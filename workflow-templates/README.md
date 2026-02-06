# Workflow Templates

This directory contains **starter workflow templates** that appear in the GitHub Actions UI when creating new workflows.

## What Are Starter Templates?

Starter templates are pre-configured workflow files that help users quickly set up common CI/CD patterns. When a repository in the Integrosa organization creates a new GitHub Actions workflow, these templates appear as quick-start options.

## How They Appear in GitHub UI

1. Go to any repository in the Integrosa organization
2. Click **"Actions"** tab
3. Click **"New workflow"**
4. Scroll to **"Workflows created by Integrosa"** section
5. Templates from this directory appear as cards with:
   - Template name (from `.properties.json`)
   - Description
   - Icon
   - "Configure" button

## Template Files

Each template consists of two files:

### 1. Workflow File (`.yml`)

The actual GitHub Actions workflow file.

**Example:** `docker-app.yml`

```yaml
name: Build and Deploy Docker App

on:
  push:
    branches: [ main, master ]
  workflow_dispatch:

jobs:
  build:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "$default_branch"
```

### 2. Properties File (`.properties.json`)

Metadata that defines how the template appears in GitHub UI.

**Example:** `docker-app.properties.json`

```json
{
  "name": "Integrosa Docker Build & Deploy",
  "description": "Build Docker image with semantic versioning",
  "iconName": "package",
  "categories": ["Deployment", "Docker", "CI"],
  "filePatterns": ["Dockerfile", "docker-compose.yml"]
}
```

## Properties File Format

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | `string` | Display name in GitHub UI |
| `description` | `string` | Short description of what template does |
| `iconName` | `string` | Icon from GitHub's icon set |

### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `categories` | `array` | Categories for filtering (e.g., "CI", "Deployment") |
| `filePatterns` | `array` | Show template when these files exist in repo |

## Available Icons

Common icon names:
- `package` - Docker/packaging workflows
- `rocket` - Deployment workflows
- `shield` - Security workflows
- `check` - Testing workflows
- `tools` - Build workflows
- `zap` - Performance workflows

[Full icon list](https://github.com/primer/octicons)

## File Pattern Matching

The `filePatterns` field determines when a template is suggested:

```json
{
  "filePatterns": [
    "Dockerfile",
    "docker-compose.yml",
    "package.json"
  ]
}
```

This template appears when the repository contains any of these files.

## Placeholder Variables

GitHub provides special placeholders that are automatically replaced:

| Placeholder | Replaced With | Example |
|-------------|---------------|---------|
| `$default_branch` | Repository's default branch name | `main` or `master` |
| `$default-branch` | Same as above (kebab-case) | `main` |
| `$repository` | Full repository name | `Integrosa/pianorama` |
| `$repo` | Repository name only | `pianorama` |

**Example usage:**

```yaml
with:
  project_name: "$default_branch"  # Becomes "pianorama"
```

## Available Templates

### Docker App Template

**File:** `docker-app.yml`

Quick-start for Docker-based applications with:
- Automatic semantic versioning
- Build and push to Scaleway registry
- Optional deployment steps
- Triggered on push to main/master

**Best for:** Node.js apps, Python apps, any containerized application

## Creating New Templates

To add a new starter template:

### 1. Create Workflow File

Create `workflow-templates/<template-name>.yml`:

```yaml
name: My Custom Workflow

on:
  push:
    branches: [ main ]

jobs:
  build:
    uses: Integrosa/.github/.github/workflows/some-workflow.yml@v1
    with:
      # Configuration
```

### 2. Create Properties File

Create `workflow-templates/<template-name>.properties.json`:

```json
{
  "name": "My Custom Workflow",
  "description": "Description of what this does",
  "iconName": "rocket",
  "categories": ["CI"],
  "filePatterns": ["package.json"]
}
```

### 3. Test Template

1. Push to repository
2. Go to any org repository
3. Click Actions → New workflow
4. Verify template appears correctly

### 4. Document Template

Add section to this README explaining:
- What the template does
- When to use it
- What it configures
- Required setup steps

## Best Practices

### Template Design

1. **Keep it simple:**
   - Include only essential configuration
   - Comment optional sections
   - Provide sensible defaults

2. **Use placeholders:**
   - Leverage `$default_branch`, `$repository`
   - Reduce manual configuration

3. **Add helpful comments:**
   ```yaml
   # Uncomment to add deployment
   # deploy:
   #   needs: build
   #   runs-on: homelab
   ```

4. **Reference stable versions:**
   ```yaml
   uses: Integrosa/.github/.github/workflows/docker-build.yml@v1
   ```

### Properties Best Practices

1. **Clear naming:**
   - Use descriptive, action-oriented names
   - "Build and Deploy Docker App" ✅
   - "Docker Workflow" ❌

2. **Concise descriptions:**
   - One sentence, under 120 characters
   - Explain what it does and for whom

3. **Appropriate categories:**
   - Use standard categories: CI, CD, Deployment, Testing
   - Maximum 3-4 categories

4. **Relevant file patterns:**
   - Match files that indicate the template is relevant
   - Don't be too restrictive

## Testing Templates

### Manual Testing

1. Create test repository in Integrosa org
2. Go to Actions → New workflow
3. Find your template
4. Click "Configure"
5. Verify:
   - Placeholders are replaced correctly
   - Default values are sensible
   - Workflow runs successfully

### Validation

Check workflow syntax:

```bash
# Install act (GitHub Actions local runner)
brew install act

# Validate workflow
act -l -W workflow-templates/docker-app.yml
```

## Template Visibility

### Organization-Wide Templates

Templates in this repository are visible to **all repositories** in the Integrosa organization.

### Repository-Specific Templates

For repository-specific templates, create `.github/workflows/` in that repository (not here).

## Troubleshooting

### Template Not Appearing

**Problem:** Template doesn't show in GitHub UI

**Solutions:**
1. Verify files are in `workflow-templates/` directory
2. Check `.properties.json` file syntax is valid JSON
3. Ensure both files have matching names (except extensions)
4. Wait a few minutes for GitHub to index changes
5. Check if `filePatterns` is too restrictive

### Placeholder Not Replaced

**Problem:** `$default_branch` appears literally in workflow

**Solution:** GitHub only replaces placeholders when the workflow is created via the UI "Configure" button, not when manually copied.

### Template Shows Wrong Information

**Problem:** Description or name is incorrect

**Solution:** Update `.properties.json` file and push changes. GitHub may cache for a few minutes.

## Examples

### Minimal Template

```yaml
# workflow-templates/minimal-build.yml
name: Build

on: push

jobs:
  build:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "$repository"
```

```json
// workflow-templates/minimal-build.properties.json
{
  "name": "Simple Docker Build",
  "description": "Basic Docker build and push",
  "iconName": "package"
}
```

### Advanced Template

```yaml
# workflow-templates/full-cicd.yml
name: Full CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

permissions:
  contents: write

jobs:
  test:
    runs-on: homelab
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: npm test

  build:
    needs: test
    if: github.ref == 'refs/heads/main'
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "$repository"

  deploy:
    needs: build
    runs-on: homelab
    steps:
      - name: Deploy
        run: |
          echo "Deploying ${{ needs.build.outputs.version_tag }}"
```

```json
// workflow-templates/full-cicd.properties.json
{
  "name": "Complete CI/CD Pipeline",
  "description": "Test, build, and deploy with version management",
  "iconName": "rocket",
  "categories": ["CI", "CD", "Deployment"],
  "filePatterns": ["Dockerfile", "package.json"]
}
```

## Related Documentation

- [Docker Build Workflow](../docs/docker-build-workflow.md)
- [Main README](../README.md)
- [GitHub Starter Workflows Documentation](https://docs.github.com/en/actions/using-workflows/creating-starter-workflows-for-your-organization)

---

[← Back to Main README](../README.md)
