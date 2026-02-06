# Kubernetes Deployment PR Workflow Documentation

Complete reference for the `reusable-k8s-deploy-pr.yml` workflow.

## Overview

This reusable workflow automates the creation of deployment pull requests to your Infrastructure-as-Code (IaC) repository. It updates Kubernetes deployment manifests with new Docker image versions and creates a PR for review before deployment.

**Use this workflow after building a Docker image to automate the deployment process.**

## Usage

```yaml
jobs:
  build:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "my-app"

  deploy:
    needs: build
    uses: Integrosa/.github/.github/workflows/reusable-k8s-deploy-pr.yml@v1
    with:
      app_name: "my-app"
      k8s_namespace: "k3s/apps/my-app"
      docker_image_path: ${{ needs.build.outputs.docker_image_path }}
      docker_image_full: ${{ needs.build.outputs.docker_image_full }}
      version_tag: ${{ needs.build.outputs.version_tag }}
    secrets:
      iac_token: ${{ secrets.ARGOCD_IAC_UPDATE_TOKEN }}
```

## Inputs

### Required Inputs

| Input | Type | Description | Example |
|-------|------|-------------|---------|
| `app_name` | `string` | Application name for PR title and commit message | `"pianorama"` |
| `k8s_namespace` | `string` | Kubernetes namespace path in IaC repo | `"k3s/apps/wrpiano"` |
| `docker_image_path` | `string` | Base Docker image path without tag | `rg.fr-par.scw.cloud/integrosa/pianorama` |
| `docker_image_full` | `string` | Full Docker image with version tag | `rg.fr-par.scw.cloud/integrosa/pianorama:v1.2.3` |
| `version_tag` | `string` | Version tag | `"v1.2.3"` |

### Optional Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `iac_repository` | `string` | `"Integrosa/cluster-iac"` | Infrastructure-as-Code repository |
| `deployment_files` | `string` | `"deployment.yaml"` | Space-separated list of files to update |
| `commit_message` | `string` | (auto-detected) | Original commit message |
| `runs_on` | `string` | `"homelab"` | Runner label |
| `pr_labels` | `string` | `"automated,deployment"` | Comma-separated PR labels |
| `environment` | `string` | `"production"` | Deployment environment name |

### Required Secrets

| Secret | Description |
|--------|-------------|
| `iac_token` | GitHub token with write access to IaC repository |

## How It Works

1. **Checkout source repository** - Gets commit information
2. **Get commit message** - Extracts commit message for PR body
3. **Checkout IaC repository** - Clones infrastructure repository
4. **Update deployment files** - Uses `sed` to replace image tags
5. **Create Pull Request** - Creates PR with deployment details

## Deployment File Updates

The workflow uses `sed` to replace Docker image references:

**Before:**
```yaml
image: rg.fr-par.scw.cloud/integrosa/pianorama:v1.0.0
```

**After:**
```yaml
image: rg.fr-par.scw.cloud/integrosa/pianorama:v1.2.3
```

## Complete Examples

### Basic Usage

```yaml
name: Build and Deploy

on:
  push:
    branches: [ main ]

permissions:
  contents: write

jobs:
  build:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "my-app"

  deploy:
    needs: build
    uses: Integrosa/.github/.github/workflows/reusable-k8s-deploy-pr.yml@v1
    with:
      app_name: "my-app"
      k8s_namespace: "k3s/apps/my-app"
      docker_image_path: ${{ needs.build.outputs.docker_image_path }}
      docker_image_full: ${{ needs.build.outputs.docker_image_full }}
      version_tag: ${{ needs.build.outputs.version_tag }}
    secrets:
      iac_token: ${{ secrets.ARGOCD_IAC_UPDATE_TOKEN }}
```

### Multiple Deployment Files

Update multiple Kubernetes manifests:

```yaml
deploy:
  needs: build
  uses: Integrosa/.github/.github/workflows/reusable-k8s-deploy-pr.yml@v1
  with:
    app_name: "my-app"
    k8s_namespace: "k3s/apps/my-app"
    deployment_files: "deployment.yaml migration-job.yaml cronjob.yaml"
    docker_image_path: ${{ needs.build.outputs.docker_image_path }}
    docker_image_full: ${{ needs.build.outputs.docker_image_full }}
    version_tag: ${{ needs.build.outputs.version_tag }}
  secrets:
    iac_token: ${{ secrets.ARGOCD_IAC_UPDATE_TOKEN }}
```

### Custom Environment

Deploy to staging environment:

```yaml
deploy-staging:
  needs: build
  uses: Integrosa/.github/.github/workflows/reusable-k8s-deploy-pr.yml@v1
  with:
    app_name: "my-app"
    k8s_namespace: "k3s/apps/my-app-staging"
    environment: "staging"
    pr_labels: "automated,deployment,staging"
    docker_image_path: ${{ needs.build.outputs.docker_image_path }}
    docker_image_full: ${{ needs.build.outputs.docker_image_full }}
    version_tag: ${{ needs.build.outputs.version_tag }}
  secrets:
    iac_token: ${{ secrets.ARGOCD_IAC_UPDATE_TOKEN }}
```

### Multi-Environment Deployment

Deploy to both staging and production:

```yaml
jobs:
  build:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "my-app"

  deploy-staging:
    needs: build
    uses: Integrosa/.github/.github/workflows/reusable-k8s-deploy-pr.yml@v1
    with:
      app_name: "my-app"
      k8s_namespace: "k3s/apps/my-app-staging"
      environment: "staging"
      docker_image_path: ${{ needs.build.outputs.docker_image_path }}
      docker_image_full: ${{ needs.build.outputs.docker_image_full }}
      version_tag: ${{ needs.build.outputs.version_tag }}
    secrets:
      iac_token: ${{ secrets.ARGOCD_IAC_UPDATE_TOKEN }}

  deploy-production:
    needs: build
    uses: Integrosa/.github/.github/workflows/reusable-k8s-deploy-pr.yml@v1
    with:
      app_name: "my-app"
      k8s_namespace: "k3s/apps/my-app"
      environment: "production"
      docker_image_path: ${{ needs.build.outputs.docker_image_path }}
      docker_image_full: ${{ needs.build.outputs.docker_image_full }}
      version_tag: ${{ needs.build.outputs.version_tag }}
    secrets:
      iac_token: ${{ secrets.ARGOCD_IAC_UPDATE_TOKEN }}
```

## Required IaC Repository Setup

### Directory Structure

Your IaC repository should follow this structure:

```
cluster-iac/
└── k3s/
    └── apps/
        └── my-app/
            ├── deployment.yaml
            ├── service.yaml
            └── ingress.yaml
```

### Deployment File Format

Deployment files must contain an `image:` field:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: app
        image: rg.fr-par.scw.cloud/integrosa/my-app:v1.0.0  # This will be updated
        ports:
        - containerPort: 3000
```

## GitHub Token Setup

### Create Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Name: `ArgoCD IaC Updates`
4. Expiration: 90 days (set renewal reminder)
5. Select scopes:
   - ✅ `repo` (Full control of private repositories)
6. Generate and copy token

### Add as Repository Secret

1. Go to repository settings → Secrets and variables → Actions → Secrets
2. Click "New repository secret"
3. Name: `ARGOCD_IAC_UPDATE_TOKEN`
4. Paste token value
5. Save

## PR Format

The created PR includes:

```markdown
## 🤖 Automated Deployment PR

This PR was automatically generated by the CI/CD pipeline.

### 📦 Release Info
| | |
|---|---|
| **Application** | `my-app` |
| **Version** | `v1.2.3` |
| **Environment** | `production` |
| **Image** | `rg.fr-par.scw.cloud/integrosa/my-app:v1.2.3` |
| **Namespace** | `k3s/apps/my-app` |
| **Commit** | [`abc123`](link) |
| **Change** | feat: add user authentication |

### 📝 Updated Files
```
deployment.yaml migration-job.yaml
```

### ✅ Merge to Deploy
Merging this PR will trigger ArgoCD to deploy the new version to **production**.
```

## Troubleshooting

### PR Not Created

**Error:**
```
Resource not accessible by integration
```

**Solution:** Ensure `ARGOCD_IAC_UPDATE_TOKEN` secret has proper `repo` permissions.

### File Not Found

**Warning in logs:**
```
Warning: File deployment.yaml not found, skipping...
```

**Solution:** Verify:
1. `k8s_namespace` path is correct
2. `deployment_files` names match actual files
3. IaC repository structure matches expected format

### Image Not Updated

**Solution:** Check that deployment files contain:
```yaml
image: <exact-match-to-docker_image_path>:tag
```

The `sed` command requires exact match of the base image path.

### Token Expired

**Error:**
```
Authentication failed
```

**Solution:** Regenerate GitHub token and update `ARGOCD_IAC_UPDATE_TOKEN` secret.

## Security Considerations

### Token Permissions

Use minimal required permissions:
- ✅ `repo` scope for private repositories
- ❌ Avoid admin or org-level permissions

### Token Rotation

Rotate tokens regularly:
- Set 90-day expiration
- Set calendar reminder for renewal
- Update secret before expiration

### Branch Protection

Protect IaC repository branches:
- Require PR reviews before merge
- Require status checks
- Prevent force pushes

## Integration with ArgoCD

This workflow creates PRs that trigger ArgoCD deployments:

1. **PR Created** → ArgoCD detects changes (via webhook or polling)
2. **PR Merged** → ArgoCD syncs application
3. **App Deployed** → Kubernetes cluster updated

### ArgoCD Configuration

Ensure ArgoCD is configured to:
- Watch the IaC repository
- Auto-sync on main branch changes (or manual sync)
- Track the correct path (e.g., `k3s/apps/my-app`)

## Related Documentation

- [Docker Build Workflow](docker-build-workflow.md)
- [Organization Setup Guide](organization-setup.md)
- [Versioning Strategy](versioning-strategy.md)

---

[← Back to Main README](../README.md)
