# Compose Deploy PR Workflow

`reusable-compose-deploy-pr.yml` — bumps an application's image tag in the Docker Compose
stack (`Integrosa/cluster-iac`) and opens a pull request.

> Replaces the former `reusable-k8s-deploy-pr.yml`. The cluster moved from k3s/ArgoCD to a
> single-VPS Docker Compose stack, so deployments are a tag bump in `compose/docker-compose.yml`
> rather than a Kubernetes manifest change.

## What it does

1. Validates that `version_tag` looks like `vMAJOR.MINOR.PATCH`.
2. Checks out the IaC repository (`Integrosa/cluster-iac` by default).
3. Bumps the image tag on **every line** that references the given `image_path`. Because an
   app and its `*-migrate` one-shot share the same image, both are bumped to the same tag in
   one pass (apps without a migrate, e.g. ksef, just have a single line).
4. Fails if the image path isn't found or nothing changed (wrong path / already at that tag).
5. Opens a PR (`peter-evans/create-pull-request`) against the IaC repo.

**Deploy stays manual.** Merging the PR only updates the source of truth. To roll it out, run
`cd compose && make deploy` from the workstation. (Auto-deploy on merge can be added later.)

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `app_name` | yes | – | Used in the PR title and branch name |
| `image_path` | yes | – | Base image path without tag — pass the build's `docker_image_path` output (e.g. `rg.pl-waw.scw.cloud/integrosa/integrosa`) |
| `version_tag` | yes | – | Tag to set, e.g. `v1.2.3` |
| `iac_repository` | no | `Integrosa/cluster-iac` | Repo to open the PR against |
| `compose_path` | no | `compose/docker-compose.yml` | Compose file inside the IaC repo |
| `runs_on` | no | `ubuntu-latest` | Runner |
| `pr_labels` | no | `automated,deployment` | PR labels |
| `environment` | no | `production` | Shown in the PR title only |

## Secrets

| Secret | Required | Description |
|--------|----------|-------------|
| `iac_token` | yes | GitHub token with write access to the IaC repo (to push the branch and open the PR). Currently passed as `ARGOCD_IAC_UPDATE_TOKEN` — legacy name, rename later. |

## Usage

```yaml
jobs:
  build:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "integrosa"
    secrets: inherit

  deploy:
    needs: build
    uses: Integrosa/.github/.github/workflows/reusable-compose-deploy-pr.yml@v1
    with:
      app_name: "integrosa"
      image_path: ${{ needs.build.outputs.docker_image_path }}
      version_tag: ${{ needs.build.outputs.version_tag }}
    secrets:
      iac_token: ${{ secrets.ARGOCD_IAC_UPDATE_TOKEN }}
```
