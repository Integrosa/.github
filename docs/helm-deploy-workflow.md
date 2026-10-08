# Helm Deploy Workflow

`reusable-helm-deploy.yml` deploys a Helm chart from the calling repository to the
integrosa-platform k3s cluster. It logs in with a short-lived GitHub OIDC token, so no cluster
credential is stored in GitHub (integrosa_platform ADR 0030).

## Call it from `@main` only

The cluster accepts a token only when its `job_workflow_ref` claim is exactly
`Integrosa/.github/.github/workflows/reusable-helm-deploy.yml@refs/heads/main`. A caller that uses
`@v1`, `@v1.4.0` or a SHA gets a token with a different `job_workflow_ref`, and every API call
fails with `401 Unauthorized`. `main` of this repository is protected by a ruleset (pull request
required, no force push, no deletion), because it decides what may deploy to the cluster.

The cluster also requires:

- organization `Integrosa` (`repository_owner_id` 258306423),
- `ref` = `refs/heads/main` and `event_name` = `push` or `workflow_dispatch`,
- a RoleBinding `deployer` in the tenant namespace naming the user
  `github:258306423/<repository id>` (set up in `integrosa_platform`, `platform/tenants/<tenant>/app`).

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

The API address and the cluster CA are fixed in the workflow, not inputs: a caller must not be able
to send a token the cluster accepts to another host. Rotating the cluster CA means a PR here
(integrosa_platform `docs/runbooks/host.md`, CA rotation).

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `release` | yes | – | Helm release name |
| `namespace` | yes | – | Tenant namespace |
| `chart_path` | yes | – | Chart subdirectory of the calling repository, e.g. `deploy/chart` (not the repository root; must contain `Chart.yaml`; chart dependencies must be vendored in its `charts/`, the workflow does not run `helm dependency build`) |
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

1. Checks the inputs (digest format, registry path, DNS names, relative chart directory with a
   `Chart.yaml`, the `images` JSON shape, `timeout`) and writes the `--set-string` arguments used by
   steps 3 and 7.
2. Installs Helm v4.3.0 and verifies its pinned SHA-256.
3. Refuses plain Secrets: renders the chart (`helm template` with the deploy values and the
   SealedSecret API declared and `crds/` included) and fails before any cluster call when a rendered
   manifest, or an element of an `items` list at any depth (Helm flattens those), is a `v1` `Secret`
   (hooks included; a reference to a Secret inside another object does not count). App secrets belong in a SealedSecret, sealed with the public certificate in
   [`sealed-secrets/`](../sealed-secrets/README.md). This is a best-effort early check (offline
   rendering has no `lookup` and always looks like a first install); the cluster is the real gate:
   the CI user may write only Helm release Secrets in a tenant namespace (integrosa_platform ADR 0033).
4. Writes a kubeconfig whose user is an exec plugin: every Helm or kubectl process asks GitHub for
   a fresh OIDC token (audience `integrosa-platform`). The token never lands on disk.
5. Prints the token's claims (never the token) and, as a non-blocking diagnostic,
   `kubectl auth whoami`.
6. Never deploys an older commit than the last deploy. Every deploy records `deploy <sha>` as the
   Helm revision description; only revisions that succeeded (`deployed`, `superseded`) count. A run
   deploys only a commit that descends from the last recorded one (GitHub compare API). An older
   commit (slow build, re-run of an old run) is skipped with a warning; the commit that is already
   recorded is not deployed again (notice); both jobs stay green. A diverged history or a failed
   compare fails the job. Runs of one release wait in a queue (`concurrency` with `queue: max`,
   so a waiting run is never cancelled by a later one).
7. `helm upgrade --install --rollback-on-failure --wait --timeout <timeout>` (default 5m): a failed
   upgrade rolls back to the last good release, and a failed first install is removed. Helm applies
   the timeout to each hook and to the wait separately, in the upgrade and again in the rollback: a
   chart with one pre-upgrade hook and no rollback hooks needs at most 4 x timeout. The job has
   `timeout-minutes: 45` (4 x 10m plus setup), so it is not killed in the middle of a rollback; a chart
   with more hooks needs a shorter timeout.

Rolling back a bad version that deployed fine: `helm rollback <release> <revision>` by the platform
owner, then a revert on `main` (re-running any earlier run does nothing, see step 6).

If a run is cancelled while Helm is working, the release can stay in `pending-upgrade`,
`pending-rollback` or `pending-install`, and Helm then refuses new upgrades ("another operation
(install/upgrade/rollback) is in progress"). The platform owner fixes it with `helm rollback` to an
explicit revision, the newest one that is `deployed` or `superseded` (without a revision Helm goes
back one step, which can be the failed upgrade), or `helm uninstall` for a first install stuck in
`pending-install`: integrosa_platform
`docs/runbooks/platform.md`, section "Wdrożenie aplikacji z CI: sytuacje kryzysowe".
