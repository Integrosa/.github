# Docker Build Workflow Documentation

Complete reference for the `reusable-docker-build.yml` workflow.

## Overview

This reusable workflow automates Docker image building with semantic versioning, pushing to Scaleway Container Registry, and creating git tags. It follows conventional commit patterns for automatic version bumping.

## Usage

```yaml
jobs:
  build:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "my-app"
```

## Inputs

### Required Inputs

| Input | Type | Description | Example |
|-------|------|-------------|---------|
| `organization_name` | `string` | Organization name for Docker image path | `"integrosa"` |
| `project_name` | `string` | Project/image name | `"pianorama"` |

### Optional Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `runs_on` | `string` | `"homelab"` | Runner label to use for the build job |
| `tag_prefix` | `string` | `"v"` | Prefix for git tags (e.g., `v1.2.3`) |
| `major_pattern` | `string` | `"(BREAKING CHANGE:\|!:)"` | Regex pattern for major version bumps |
| `minor_pattern` | `string` | `"feat:"` | Regex pattern for minor version bumps |
| `push_git_tag` | `boolean` | `true` | Whether to create and push git tags |
| `dockerfile_path` | `string` | `"./Dockerfile"` | Path to Dockerfile relative to repository root |
| `docker_context` | `string` | `"."` | Docker build context path |

## Outputs

All outputs are available to downstream jobs using `needs.<job-id>.outputs.<output-name>`.

| Output | Description | Example Value |
|--------|-------------|---------------|
| `version` | Semantic version without prefix | `1.2.3` |
| `version_tag` | Version with tag prefix | `v1.2.3` |
| `docker_image_full` | Full Docker image reference with version tag | `rg.fr-par.scw.cloud/integrosa/pianorama:v1.2.3` |
| `docker_image_path` | Base Docker image path without tag | `rg.fr-par.scw.cloud/integrosa/pianorama` |

## Semantic Versioning

The workflow uses **conventional commits** to automatically determine version bumps:

### Version Bump Rules

| Commit Pattern | Version Bump | Example Commit | Result |
|----------------|--------------|----------------|--------|
| `feat:` | **Minor** (0.X.0) | `feat: add user authentication` | `v0.1.0` → `v0.2.0` |
| `BREAKING CHANGE:` or `!:` | **Major** (X.0.0) | `feat!: redesign API` | `v0.9.0` → `v1.0.0` |
| All others | **Patch** (0.0.X) | `fix: resolve login bug` | `v0.1.0` → `v0.1.1` |

### Common Commit Prefixes

- `feat:` - New features (minor bump)
- `fix:` - Bug fixes (patch bump)
- `docs:` - Documentation changes (patch bump)
- `chore:` - Maintenance tasks (patch bump)
- `refactor:` - Code refactoring (patch bump)
- `style:` - Code style changes (patch bump)
- `test:` - Test changes (patch bump)
- `ci:` - CI/CD changes (patch bump)

### Custom Patterns

You can customize version bump patterns:

```yaml
jobs:
  build:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "my-app"
      major_pattern: "(MAJOR:|breaking:)"
      minor_pattern: "(feature:|enhancement:)"
```

## Docker Image Naming

Images follow this naming convention:

```
<REGISTRY_URL>/<organization_name>/<project_name>:<version_tag>
```

**Example:**
```
rg.fr-par.scw.cloud/integrosa/pianorama:v1.2.3
```

The workflow also pushes a `latest` tag:
```
rg.fr-par.scw.cloud/integrosa/pianorama:latest
```

## Required Organization Configuration

### Organization Variables

Set at: `https://github.com/organizations/Integrosa/settings/variables/actions`

```
REGISTRY_URL=rg.fr-par.scw.cloud/integrosa
REGISTRY_USERNAME=nologin
```

### Organization Secrets

Set at: `https://github.com/organizations/Integrosa/settings/secrets/actions`

```
REGISTRY_TOKEN=<your-scaleway-registry-token>
```

## Permissions

The workflow requires the following permissions:

```yaml
permissions:
  contents: write  # Required to push git tags
```

This must be set in the calling workflow:

```yaml
name: Build

on:
  push:
    branches: [ main ]

permissions:
  contents: write  # ← Required!

jobs:
  build:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
```

## Complete Examples

### Basic Usage

```yaml
name: Build and Push

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
```

### Custom Dockerfile Location

```yaml
jobs:
  build:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "my-app"
      dockerfile_path: "./docker/Dockerfile.production"
      docker_context: "./docker"
```

### Disable Git Tagging

```yaml
jobs:
  build:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "my-app"
      push_git_tag: false
```

### Using Outputs for Deployment

```yaml
jobs:
  build:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "my-app"

  deploy:
    needs: build
    runs-on: homelab
    steps:
      - name: Update Kubernetes deployment
        run: |
          kubectl set image deployment/my-app \
            app=${{ needs.build.outputs.docker_image_full }}

      - name: Verify deployment
        run: |
          echo "Deployed version: ${{ needs.build.outputs.version_tag }}"
          kubectl rollout status deployment/my-app
```

### Multi-Service Monorepo

```yaml
jobs:
  build-api:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "my-app-api"
      dockerfile_path: "./services/api/Dockerfile"
      docker_context: "./services/api"

  build-web:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "my-app-web"
      dockerfile_path: "./services/web/Dockerfile"
      docker_context: "./services/web"

  deploy:
    needs: [build-api, build-web]
    runs-on: homelab
    steps:
      - name: Deploy services
        run: |
          echo "API: ${{ needs.build-api.outputs.docker_image_full }}"
          echo "Web: ${{ needs.build-web.outputs.docker_image_full }}"
```

## Troubleshooting

### Permission Denied on Git Tag Push

**Error:**
```
fatal: unable to access 'https://github.com/Integrosa/my-app.git/':
The requested URL returned error: 403
```

**Solution:** Ensure `permissions: contents: write` is set in the calling workflow.

### Docker Login Failed

**Error:**
```
Error response from daemon: Get "https://rg.fr-par.scw.cloud/v2/": unauthorized
```

**Solution:** Check that:
1. `REGISTRY_URL` organization variable is set correctly
2. `REGISTRY_USERNAME` organization variable is set
3. `REGISTRY_TOKEN` organization secret is set and valid

### Semantic Version Not Incrementing

**Solution:** Check your commit messages follow conventional commits format:
- Good: `feat: add new feature`
- Bad: `added new feature`

### Docker Build Failed

**Error:**
```
failed to solve with frontend dockerfile.v0
```

**Solution:** Verify:
1. `dockerfile_path` points to valid Dockerfile
2. `docker_context` contains all required build files
3. Dockerfile syntax is correct

## Advanced Configuration

### Custom Runner

If using GitHub-hosted runners:

```yaml
jobs:
  build:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "my-app"
      runs_on: "ubuntu-latest"
```

### Environment-Specific Builds

Build different versions for different environments:

```yaml
jobs:
  build-staging:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "my-app-staging"
      tag_prefix: "staging-v"

  build-production:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "my-app"
      tag_prefix: "v"
```

## Workflow Steps

The workflow executes these steps:

1. **Checkout code** - Clones repository with full git history
2. **Get semantic version** - Analyzes commits to determine version
3. **Login to registry** - Authenticates with Scaleway Container Registry
4. **Build Docker image** - Builds image with version tag and latest tag
5. **Push to registry** - Pushes both version and latest tags
6. **Create git tag** - Creates and pushes git tag (if enabled)
7. **Clean up** - Prunes old Docker images to free disk space

## Related Documentation

- [Organization Setup Guide](organization-setup.md)
- [Versioning Strategy](versioning-strategy.md)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)

---

[← Back to Main README](../README.md)
