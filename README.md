# Integrosa GitHub Organization Templates

Central repository for GitHub Actions reusable workflows and starter templates used across Integrosa organization.

> **📍 New Location**: This repository has been migrated from `Integrosa/reusable_workflows` to the official `.github` organization repository. Starter workflow templates will now appear in the GitHub Actions UI!

## 🎯 Purpose

This repository provides standardized, reusable GitHub Actions workflows that can be shared across all Integrosa projects. It ensures consistency, reduces duplication, and simplifies maintenance of CI/CD pipelines.

## 📦 Available Workflows

### 🐳 Docker Build Workflow

Automated Docker image building with semantic versioning, registry push, and git tagging.

**Features:**
- ✅ Semantic versioning with conventional commits
- ✅ Build and push to Scaleway Container Registry
- ✅ Automatic git tagging
- ✅ Configurable for any Docker-based project
- ✅ Support for monorepo with multiple services

[View Detailed Documentation](docs/docker-build-workflow.md)

### 🚀 Compose Deploy PR Workflow

Automated creation of deployment pull requests that bump an app's image tag in the
Docker Compose stack (`Integrosa/cluster-iac`).

**Features:**
- ✅ Bumps the image tag in `compose/docker-compose.yml`
- ✅ Matches by image path, so an app's `*-migrate` one-shot is bumped to the same tag
- ✅ Creates PRs with deployment details (the deploy itself stays manual: `make deploy`)
- ✅ Validates the version tag and fails if the image isn't found

> Replaces the former Kubernetes deployment workflow (k3s/ArgoCD were removed).

[View Detailed Documentation](docs/compose-deploy-pr-workflow.md)

### ☸️ Helm Deploy Workflow

Deploys an app's Helm chart to the integrosa-platform k3s cluster with a short-lived GitHub OIDC
token: no cluster credential in GitHub.

**Features:**
- ✅ Deploys by image digest with `--rollback-on-failure`
- ✅ Never deploys an older commit than the last deploy; runs of one release never overlap
- ✅ Helm pinned by checksum, token fetched per use and never written to disk

> ⚠️ Call it as `@main`. The cluster rejects tokens from any other ref of this workflow.

[View Detailed Documentation](docs/helm-deploy-workflow.md)

## 🚀 Quick Start

### Option 1: Use Starter Template (Easiest)

1. Go to your repository on GitHub
2. Click **"Actions"** → **"New workflow"**
3. Find **"Integrosa Docker Build & Deploy"** template
4. Click **"Configure"** and customize as needed

### Option 2: Create Workflow Manually

Create `.github/workflows/build.yml` in your repository:

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
      project_name: "your-app-name"
    secrets: inherit
```

### Option 3: View Examples

See the [examples/](examples/) directory for complete workflow examples:
- **Basic Docker Build** - Simple build and push
- **Build with Deployment** - Build and create deployment PR
- **Multi-Service Build** - Monorepo with multiple services

## ⚙️ Organization Setup

Before using these workflows, ensure your organization has the following configured:

### Required Organization Variables

Set these at: `https://github.com/organizations/Integrosa/settings/variables/actions`

| Variable | Description | Example |
|----------|-------------|---------|
| `REGISTRY_URL` | Container registry host (no namespace; the image path is `REGISTRY_URL/<org>/<project>`) | `rg.pl-waw.scw.cloud` |
| `REGISTRY_NAMESPACE` | Registry namespace (used for the `docker login` target) | `integrosa` |
| `REGISTRY_USERNAME` | Registry username | `nologin` |

### Required Organization Secrets

Set these at: `https://github.com/organizations/Integrosa/settings/secrets/actions`

| Secret | Description |
|--------|-------------|
| `REGISTRY_TOKEN` | Container registry access token |

### Optional Repository Secrets

For deployment workflows:

| Secret | Description |
|--------|-------------|
| `ARGOCD_IAC_UPDATE_TOKEN` | GitHub token for creating deployment PRs in `cluster-iac`. ⚠️ Legacy name (ArgoCD is gone) — rename to e.g. `CLUSTER_IAC_TOKEN` later. |

See [Organization Setup Guide](docs/organization-setup.md) for detailed instructions.

## 📌 Versioning

This repository follows semantic versioning. You can reference workflows by:

- **Major version** (recommended): `@v1` - automatically gets latest v1.x.x
- **Specific version**: `@v1.0.0` - pins to exact version
- **Branch**: `@main` - uses latest (not recommended for production), except `reusable-helm-deploy.yml`, which works only from `@main` (see its documentation)

**Example:**
```yaml
uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
```

See [Versioning Strategy](docs/versioning-strategy.md) for migration guides and breaking changes.

## 📚 Documentation

- [Docker Build Workflow Documentation](docs/docker-build-workflow.md) - Complete reference
- [Compose Deploy PR Workflow Documentation](docs/compose-deploy-pr-workflow.md) - Deployment automation
- [Helm Deploy Workflow Documentation](docs/helm-deploy-workflow.md) - Deploys to the k3s cluster over GitHub OIDC
- [Organization Setup Guide](docs/organization-setup.md) - Configuration instructions
- [Versioning Strategy](docs/versioning-strategy.md) - Version management
- [Workflow Templates Guide](workflow-templates/README.md) - Using starter templates

## 🤝 Contributing

We welcome contributions! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting pull requests.

**Quick guidelines:**
- Follow existing workflow patterns
- Document all inputs and outputs
- Provide usage examples
- Test workflows before submitting
- Update documentation

## 📖 Examples

### Basic Docker Build

```yaml
jobs:
  build:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "my-app"
```

### Complete CI/CD Pipeline (Build + Deploy)

```yaml
jobs:
  build:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "my-app"

  deploy:
    needs: build
    uses: Integrosa/.github/.github/workflows/reusable-compose-deploy-pr.yml@v1
    with:
      app_name: "my-app"
      image_path: ${{ needs.build.outputs.docker_image_path }}
      version_tag: ${{ needs.build.outputs.version_tag }}
    secrets:
      iac_token: ${{ secrets.ARGOCD_IAC_UPDATE_TOKEN }}
```

### Custom Dockerfile Path

```yaml
jobs:
  build:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "my-app"
      dockerfile_path: "./docker/Dockerfile.prod"
      docker_context: "./docker"
```

## 🔮 Future Enhancements

Planned workflows for future releases:

- 📦 `reusable-npm-ci.yml` - npm test and build workflow
- 🐍 `reusable-python-ci.yml` - Python testing workflow
- 🔒 `reusable-security-scan.yml` - Security scanning workflow
- 🧪 `reusable-e2e-tests.yml` - End-to-end testing workflow

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/Integrosa/.github/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Integrosa/.github/discussions)
- **Documentation**: Check the [docs/](docs/) directory

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Maintained by Integrosa Organization** | [Organization Homepage](https://github.com/Integrosa)
