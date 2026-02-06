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

### 🚀 Kubernetes Deployment PR Workflow

Automated creation of deployment pull requests to your Infrastructure-as-Code repository.

**Features:**
- ✅ Updates Kubernetes manifests with new image versions
- ✅ Creates PRs with deployment details
- ✅ Supports multiple environments (staging, production)
- ✅ Multiple deployment files support
- ✅ Integrates with ArgoCD for GitOps deployments

[View Detailed Documentation](docs/k8s-deploy-pr-workflow.md)

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
      runs_on: "homelab"
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
| `REGISTRY_URL` | Container registry URL | `rg.fr-par.scw.cloud/integrosa` |
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
| `ARGOCD_IAC_UPDATE_TOKEN` | GitHub token for creating deployment PRs |

See [Organization Setup Guide](docs/organization-setup.md) for detailed instructions.

## 📌 Versioning

This repository follows semantic versioning. You can reference workflows by:

- **Major version** (recommended): `@v1` - automatically gets latest v1.x.x
- **Specific version**: `@v1.0.0` - pins to exact version
- **Branch**: `@main` - uses latest (not recommended for production)

**Example:**
```yaml
uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
```

See [Versioning Strategy](docs/versioning-strategy.md) for migration guides and breaking changes.

## 📚 Documentation

- [Docker Build Workflow Documentation](docs/docker-build-workflow.md) - Complete reference
- [Kubernetes Deployment PR Workflow Documentation](docs/k8s-deploy-pr-workflow.md) - Deployment automation
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
