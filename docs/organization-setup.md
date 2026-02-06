# Organization Setup Guide

This guide explains how to configure your GitHub organization to use the Integrosa reusable workflows.

## Overview

The reusable workflows require certain organization-level variables and secrets to be configured. These are shared across all repositories in the organization, ensuring consistency and simplifying configuration.

## Prerequisites

You need **organization admin** permissions to configure variables and secrets.

## Required Configuration

### 1. Organization Variables

Organization variables are non-sensitive configuration values that can be used across all workflows.

**Configure at:** `https://github.com/organizations/Integrosa/settings/variables/actions`

#### REGISTRY_URL

The base URL of your container registry (without namespace).

- **Name:** `REGISTRY_URL`
- **Value:** `rg.pl-waw.scw.cloud`
- **Description:** Scaleway Container Registry base URL (Warsaw region)
- **Visibility:** Can be visible to all repositories

**To set:**
1. Go to organization settings → Actions → Variables
2. Click "New organization variable"
3. Enter name: `REGISTRY_URL`
4. Enter value: `rg.pl-waw.scw.cloud`
5. Select visibility (all repositories recommended)
6. Click "Add variable"

#### REGISTRY_NAMESPACE

The namespace for your container registry (used for Docker login authentication).

- **Name:** `REGISTRY_NAMESPACE`
- **Value:** `integrosa`
- **Description:** Scaleway Container Registry namespace for organization
- **Visibility:** Can be visible to all repositories

**To set:**
1. Go to organization settings → Actions → Variables
2. Click "New organization variable"
3. Enter name: `REGISTRY_NAMESPACE`
4. Enter value: `integrosa`
5. Select visibility (all repositories recommended)
6. Click "Add variable"

#### REGISTRY_USERNAME

The username for authenticating with the container registry.

- **Name:** `REGISTRY_USERNAME`
- **Value:** `nologin` (Scaleway's default username)
- **Description:** Container registry authentication username
- **Visibility:** Can be visible to all repositories

**To set:**
1. Go to organization settings → Actions → Variables
2. Click "New organization variable"
3. Enter name: `REGISTRY_USERNAME`
4. Enter value: `nologin`
5. Select visibility (all repositories recommended)
6. Click "Add variable"

### 2. Organization Secrets

Organization secrets are sensitive values that are encrypted and only available during workflow execution.

**Configure at:** `https://github.com/organizations/Integrosa/settings/secrets/actions`

#### REGISTRY_TOKEN

The authentication token for pushing to the container registry.

- **Name:** `REGISTRY_TOKEN`
- **Description:** Scaleway Container Registry authentication token
- **Visibility:** Select repositories that need to build Docker images

**How to obtain the token:**

1. Log in to Scaleway Console
2. Go to Container Registry section
3. Select your registry (`integrosa`)
4. Go to "Settings" or "Credentials"
5. Generate a new token or use existing one
6. Copy the token value

**To set in GitHub:**
1. Go to organization settings → Secrets and variables → Actions → Secrets
2. Click "New organization secret"
3. Enter name: `REGISTRY_TOKEN`
4. Paste the Scaleway token as value
5. Select repository visibility (all or specific repositories)
6. Click "Add secret"

### 3. Optional: Repository Secrets

Some workflows (like deployment workflows) may require additional repository-level secrets.

#### ARGOCD_IAC_UPDATE_TOKEN

GitHub personal access token for creating deployment PRs in the infrastructure repository.

- **Name:** `ARGOCD_IAC_UPDATE_TOKEN`
- **Type:** Repository secret (not organization-wide)
- **Description:** GitHub PAT with repo permissions for cluster-iac
- **Required for:** Deployment workflows that create PRs

**How to create the token:**

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a descriptive name: `ArgoCD IaC Updates`
4. Set expiration (recommended: 90 days with renewal reminder)
5. Select scopes:
   - ✅ `repo` (Full control of private repositories)
6. Click "Generate token"
7. Copy the token immediately (won't be shown again)

**To set in repository:**
1. Go to repository settings → Secrets and variables → Actions → Secrets
2. Click "New repository secret"
3. Enter name: `ARGOCD_IAC_UPDATE_TOKEN`
4. Paste the GitHub PAT as value
5. Click "Add secret"

## Verification

After configuration, verify the setup:

### 1. Check Variables

```bash
# Organization variables should be accessible in workflows
echo "Registry URL: ${{ vars.REGISTRY_URL }}"
echo "Registry Namespace: ${{ vars.REGISTRY_NAMESPACE }}"
echo "Registry Username: ${{ vars.REGISTRY_USERNAME }}"
```

### 2. Test Docker Login

Create a test workflow:

```yaml
name: Test Registry Access

on: workflow_dispatch

jobs:
  test:
    runs-on: homelab
    steps:
      - name: Test registry login
        run: |
          echo "${{ secrets.REGISTRY_TOKEN }}" | \
            docker login ${{ vars.REGISTRY_URL }}/${{ vars.REGISTRY_NAMESPACE }} \
            -u ${{ vars.REGISTRY_USERNAME }} \
            --password-stdin

          echo "✅ Successfully logged in to registry"
```

### 3. Verify Permissions

Ensure repositories have proper access:

1. Go to organization settings → Actions → General
2. Check "Workflow permissions":
   - ✅ Read and write permissions
   - ✅ Allow GitHub Actions to create and approve pull requests (if using deployment workflows)

## Security Best Practices

### Token Rotation

Rotate sensitive tokens regularly:

- **REGISTRY_TOKEN:** Rotate every 90-180 days
- **ARGOCD_IAC_UPDATE_TOKEN:** Rotate every 90 days

Set calendar reminders for token rotation.

### Access Control

Limit secret visibility:

- Use "Selected repositories" for `REGISTRY_TOKEN` instead of "All repositories"
- Only grant access to repositories that actually build Docker images
- Review access quarterly

### Audit Logging

Monitor secret usage:

1. Go to organization settings → Audit log
2. Filter by actions:
   - `org.update_actions_secret`
   - `org.access_actions_secret`
3. Review regularly for unauthorized access

## Troubleshooting

### Problem: Workflow can't access REGISTRY_TOKEN

**Error message:**
```
Error: Input required and not supplied: registry_token
```

**Solution:**
1. Verify secret is set at organization level
2. Check secret visibility includes the repository
3. Ensure secret name is exactly `REGISTRY_TOKEN` (case-sensitive)

### Problem: Variable not found

**Error message:**
```
Error: Unable to resolve action `vars.REGISTRY_URL`
```

**Solution:**
1. Verify variable is set at organization level
2. Check variable visibility includes the repository
3. Ensure variable name matches exactly (case-sensitive)

### Problem: Permission denied when pushing tags

**Error message:**
```
fatal: unable to access 'https://github.com/...': The requested URL returned error: 403
```

**Solution:**
1. Go to repository settings → Actions → General
2. Under "Workflow permissions":
   - Select "Read and write permissions"
3. Save changes

### Problem: Docker login fails

**Error message:**
```
Error response from daemon: Get "https://rg.fr-par.scw.cloud/v2/": unauthorized
```

**Solution:**
1. Verify `REGISTRY_TOKEN` is valid (try logging in manually)
2. Check token hasn't expired in Scaleway Console
3. Regenerate token if necessary
4. Update GitHub secret with new token

## Migration from Repository-Level Secrets

If you previously had repository-level secrets, migrate to organization-level:

1. **Create organization secrets** (as described above)
2. **Update workflows** to use organization secrets (no code changes needed)
3. **Delete old repository secrets**:
   - Go to each repository → Settings → Secrets
   - Delete `REGISTRY_TOKEN`, `REGISTRY_URL`, etc.
4. **Verify** workflows still work with organization secrets

## Scaleway-Specific Configuration

### Registry Setup

Ensure your Scaleway Container Registry is properly configured:

1. **Create registry** (if not exists):
   - Go to Scaleway Console → Container Registry
   - Create registry with name: `integrosa`
   - Select region: `fr-par` (Paris)

2. **Configure registry**:
   - Enable "Public" or "Private" based on needs
   - Configure retention policies if needed

3. **Generate API token**:
   - Go to registry settings
   - Generate push/pull token
   - Copy token for `REGISTRY_TOKEN` secret

### Container Registry URL Format

Scaleway registry URLs follow this format:

```
rg.<region>.scw.cloud/<namespace>
```

Example:
```
rg.fr-par.scw.cloud/integrosa
```

Where:
- `rg` = Registry
- `fr-par` = Paris region
- `scw.cloud` = Scaleway Cloud
- `integrosa` = Organization namespace

## Next Steps

After completing organization setup:

1. ✅ Test workflows in a sample repository
2. ✅ Update existing projects to use reusable workflows
3. ✅ Document project-specific configuration
4. ✅ Set up token rotation reminders
5. ✅ Train team members on workflow usage

## Related Documentation

- [Docker Build Workflow](docker-build-workflow.md)
- [Versioning Strategy](versioning-strategy.md)
- [Main README](../README.md)

## Support

For issues with organization configuration:

1. Check [Troubleshooting](#troubleshooting) section
2. Review [GitHub Actions documentation](https://docs.github.com/en/actions)
3. Contact organization admins
4. Open issue in this repository

---

[← Back to Main README](../README.md)
