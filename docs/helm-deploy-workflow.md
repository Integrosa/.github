# Helm Deploy Workflow

`reusable-helm-deploy.yml` deploys a Helm chart from the calling repository to one of the
organization's k3s clusters. It logs in with a short-lived GitHub OIDC token, so no cluster
credential is stored in GitHub (integrosa_platform ADR 0030).

## Clusters

The input `cluster` picks one value from a closed list (integrosa_platform ADR 0054). Each value has its
API address, CA and token audience fixed in the workflow. Any other value, an empty one included, fails
before a token is requested.

| `cluster` | API | Audience | Runner | Owner |
|-----------|-----|----------|--------|-------|
| `integrosa-platform` (default) | `https://194.163.128.14:6443` | `integrosa-platform` | the organization's self-hosted runners (group `integrosa-ci`) when the variable `CI_RUNNER` is `integrosa-ci` (the organization's, or the calling repository's, which overrides it; integrosa_platform ADR 0063), else `ubuntu-latest` | `integrosa_platform` |
| `b3net-prod` | `https://5.9.48.90:6443` | `b3net-prod` | the same as `integrosa-platform` (b3net-bare-metal-iac ADR 0018) | `b3net-bare-metal-iac` (ADR 0013, 0017, 0018) |

The workflow `Cross-audience` sends a real token minted for one cluster's audience to the other cluster's
API and expects 401, with each certificate verified by the pinned CA. Both clusters also require this
workflow's `job_workflow_ref`, which that token cannot carry, so the job proves the refusal, the
addresses and the CAs, not that the audience is the reason (that is in the APIs' logs). It is not part of
`Test`, so a cluster outage does not block releases of this repository. Runs of the
same release queue per cluster, so a deploy to one cluster never waits for the other.

## Call it from `@main` only

The cluster accepts a token only when its `job_workflow_ref` claim is exactly
`Integrosa/.github/.github/workflows/reusable-helm-deploy.yml@refs/heads/main`. A caller that uses
`@v1`, `@v1.4.0` or a SHA gets a token with a different `job_workflow_ref`, and every API call
fails with `401 Unauthorized`. `main` of this repository is protected by a ruleset (pull request
required, no force push, no deletion), because it decides what may deploy to the cluster.

Each cluster also requires:

- organization `Integrosa` (`repository_owner_id` 258306423),
- `ref` = `refs/heads/main` and `event_name` = `push` or `workflow_dispatch` (one exception, on
  `integrosa-platform` only, integrosa_platform ADR 0038: `refs/heads/staging` of `Integrosa/b3net-platform`,
  as its own user `github:<owner id>/<repo id>@staging`, bound in one staging tenant),
- a RoleBinding `deployer` in the tenant namespace naming the user
  `github:258306423/<repository id>` (set up by the cluster's owner: `integrosa_platform`
  `platform/tenants/<tenant>/app`, or `b3net-bare-metal-iac` `tenants/<tenant>`).

## Usage

```yaml
on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    permissions:
      contents: write
    with:
      organization_name: "integrosa"
      project_name: "my-app"
    secrets: inherit

  deploy:
    needs: build
    uses: Integrosa/.github/.github/workflows/reusable-helm-deploy.yml@main
    permissions:
      id-token: write
      contents: read
    with:
      release: my-app
      namespace: my-tenant
      chart_path: deploy/chart
      image_repository: ${{ needs.build.outputs.docker_image_path }}
      image_digest: ${{ needs.build.outputs.docker_image_digest }}
```

`docker_image_digest` exists from `reusable-docker-build` v1.4.0 on (and `@v1` once it points there).

For `b3net-prod`, add `cluster: b3net-prod` under `with:`. A chart that serves two environments keeps
their differences in values files next to `values.yaml` and names one with `values_file`, for example
`values_file: values-prod.yaml`.

The API addresses and the cluster CAs are fixed in the workflow, not inputs: a caller must not be able
to send a token a cluster accepts to another host. Rotating a cluster's CA means a PR here
(integrosa_platform `docs/runbooks/host.md`; for `b3net-prod`, b3net-bare-metal-iac ADR 0017).

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `release` | yes | – | Helm release name |
| `namespace` | yes | – | Tenant namespace |
| `cluster` | no | `integrosa-platform` | Target cluster, `integrosa-platform` or `b3net-prod` (see Clusters) |
| `values_file` | no | `""` | Values file inside `chart_path`, e.g. `values-prod.yaml`: a relative path with the same rules as `chart_path`, a regular file, not in the chart's `templates/`, `crds/` or `charts/`. Passed as `--values` after the chart's `values.yaml`; the image `--set-string` arguments still take precedence over it. Pass a literal per environment job: a re-run of an already deployed commit does nothing, whatever `values_file` says, so a values change needs a new commit. Added 2026-10-18 with the owner's approval; it extends the inputs of integrosa_platform ADR 0039 |
| `app_version` | no | `""` | The release the deploy runs, `v<major>.<minor>.<patch>` with an optional `-<pre-release>` of letters and digits in dot-separated parts (e.g. `v1.4.0`, `v1.4.0-staging.abc1234`). Passed as `--set-string appVersion=<value>`; what the chart does with it is the chart's (b3net-platform sets the backend's `APP_VERSION`). A value that is not that shape fails the job before a token is requested. Added 2026-10-26 with the owner's approval (b3net-platform L-979, variant B) |
| `chart_path` | yes | – | Chart subdirectory of the calling repository, e.g. `deploy/chart` (not the repository root; must contain `Chart.yaml`; no symlink inside it or as it or its parents, since Helm follows them and a committed link could read runner files into the release; chart dependencies must be vendored in its `charts/`, the workflow does not run `helm dependency build`) |
| `image_repository` | one image | `""` | Image without tag, the build's `docker_image_path` output |
| `image_digest` | one image | `""` | `sha256:...`, the build's `docker_image_digest` output |
| `images` | several images | `""` | JSON `{"<name>": {"repository": "...", "digest": "sha256:..."}}`, 1-10 entries, name `^[a-z][a-zA-Z0-9]{0,30}$`; instead of `image_repository`/`image_digest`, never both |
| `timeout` | no | `5m` | Helm `--timeout`, `1m`-`10m`; it applies to each hook and to the wait separately, in the upgrade and again in a rollback |

With one image the chart must read `image.repository` and `image.digest` (the workflow sets both
with `--set-string`) and reference the image as `repository@digest`.

### Several images

An app made of several images (a backend, a shop, a helper service) passes them all at once, each by
digest, whether it was built in this run or not. The digests must be read after the build (a job
that needs `build` asks the registry for every image's digest); a job before the build would pin the
previous image of an app it is about to rebuild. When nothing was built, `build` is skipped, so the
`digests` and `deploy` need an `if:` that lets a skipped build through but nothing else (a failed or
cancelled build would deploy the previous digests under the new commit). Run the whole caller
workflow in one `concurrency` group with `cancel-in-progress: false`: digests read for images that
were not rebuilt must come after the previous run's build, or a newer commit can pin an older image.

```yaml
  deploy:
    needs: [plan, build, digests]
    # digests: if: ${{ !cancelled() && needs.plan.result == 'success' && contains(fromJSON('["success", "skipped"]'), needs.build.result) }}
    if: ${{ !cancelled() && contains(fromJSON('["success", "skipped"]'), needs.build.result) && needs.digests.result == 'success' }}
    permissions:
      id-token: write
      contents: read
    uses: Integrosa/.github/.github/workflows/reusable-helm-deploy.yml@main
    with:
      release: medusa
      namespace: b3net-staging
      chart_path: infra/chart
      images: ${{ needs.digests.outputs.images_json }}  # {"backend": {"repository": ..., "digest": ...}, ...}
      timeout: 10m
```

The workflow sets `images.<name>.repository` and `images.<name>.digest`, so the chart references
`{{ .Values.images.backend.repository }}@{{ .Values.images.backend.digest }}`. Names have no dots,
commas or dashes, because `--set-string` would split or nest on them and Go templates read
`.Values.images.<name>` only for plain identifiers. Helm changes only the Deployments whose digest
changed. `tests/helm-deploy-inputs.sh` runs the input checks against good and bad values (workflow
`Test` on every pull request).

## What it does

1. Selects the cluster: its API address, CA and audience, or fails on any other value.
2. Checks the inputs (digest format, registry path, DNS names, relative chart directory with a
   `Chart.yaml` and no symlink in it or as it, the `images` JSON shape, `timeout`, `values_file`) and writes the
   `--set-string` arguments, plus `--values <chart_path>/<values_file>` when given, used by steps 4 and 8.
3. Installs Helm v4.3.0 and verifies its pinned SHA-256.
4. Refuses plain Secrets: renders the chart (`helm template` with the deploy values and the
   SealedSecret API declared and `crds/` included) and fails before any cluster call when a rendered
   manifest, or an element of an `items` list at any depth (Helm flattens those), is a `v1` `Secret`
   (hooks included; a reference to a Secret inside another object does not count). App secrets belong in a SealedSecret, sealed with the public certificate in
   [`sealed-secrets/`](../sealed-secrets/README.md). This is a best-effort early check (offline
   rendering has no `lookup` and always looks like a first install); the cluster is the real gate:
   the CI user may write only Helm release Secrets in a tenant namespace (integrosa_platform ADR 0033).
5. Writes a kubeconfig whose user is an exec plugin: every Helm or kubectl process asks GitHub for
   a fresh OIDC token (the selected cluster's audience). The token never lands on disk.
6. Prints the token's claims (never the token) and, as a non-blocking diagnostic,
   `kubectl auth whoami`.
7. Never deploys an older commit than the last deploy. Every deploy records `deploy <sha>` as the
   Helm revision description; only revisions that succeeded (`deployed`, `superseded`) count. A run
   deploys only a commit that descends from the last recorded one (GitHub compare API). An older
   commit (slow build, re-run of an old run) is skipped with a warning; the commit that is already
   recorded is not deployed again (notice); both jobs stay green. A diverged history or a failed
   compare fails the job. Runs of one release wait in a queue (`concurrency` with `queue: max`,
   so a waiting run is never cancelled by a later one).
8. `helm upgrade --install --rollback-on-failure --wait --timeout <timeout>` (default 5m): a failed
   upgrade rolls back to the last good release, and a failed first install is removed. Helm applies
   the timeout to each hook and to the wait separately, in the upgrade and again in the rollback: a
   chart with one pre-upgrade hook resource, at most one post-upgrade hook resource and no rollback hooks needs at
   most 4 x timeout (pre hook, wait, post hook, then the rollback's wait; `pkg/action/upgrade.go` lines 460, 483,
   508, 589 @ v4.3.0). Helm waits for each hook resource on its own, so the count is of hook resources, not phases. The job has
   `timeout-minutes: 45` (4 x 10m plus setup), so it is not killed in the middle of a rollback; a chart
   with more hooks needs a shorter timeout.

Rolling back a bad version that deployed fine: `helm rollback <release> <revision>` by the platform
owner, then a revert on `main` (re-running any earlier run does nothing, see step 7).

If a run is cancelled while Helm is working, the release can stay in `pending-upgrade`,
`pending-rollback` or `pending-install`, and Helm then refuses new upgrades ("another operation
(install/upgrade/rollback) is in progress"). The platform owner fixes it with `helm rollback` to an
explicit revision, the newest one that is `deployed` or `superseded` (without a revision Helm goes
back one step, which can be the failed upgrade), or `helm uninstall` for a first install stuck in
`pending-install`: integrosa_platform
`docs/runbooks/platform.md`, section "Wdrożenie aplikacji z CI: sytuacje kryzysowe".
