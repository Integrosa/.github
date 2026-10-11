# Versioning Strategy

This document explains the versioning strategy for the reusable workflows repository itself.

## Overview

The `.github` repository follows **semantic versioning** (semver) to ensure predictable updates and backward compatibility.

## Version Format

Versions follow the format: `MAJOR.MINOR.PATCH`

Example: `v1.2.3`
- **Major:** Breaking changes
- **Minor:** New features (backward compatible)
- **Patch:** Bug fixes (backward compatible)

## Git Tags

Tags are created by the release workflow on every push to `main` (`.github/workflows/release.yml`,
[release-workflow.md](release-workflow.md)): the pull request's conventional title decides the bump,
and `v1` moves to each `v1.x.y`. Nothing is tagged by hand.

Workflows can be referenced by version tags:

### Major Version Tags (Recommended)

Reference the latest version within a major release:

```yaml
uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
```

This automatically uses the latest `v1.x.x` version. When we release `v1.3.0`, workflows using `@v1` automatically benefit from the update.

**Benefits:**
- ✅ Automatic minor/patch updates
- ✅ No breaking changes
- ✅ Security fixes applied automatically
- ✅ New features available immediately

**Best for:** Production workflows that want latest features while maintaining stability.

### Specific Version Tags

Pin to an exact version:

```yaml
uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1.2.3
```

**Benefits:**
- ✅ Predictable, no surprises
- ✅ Easy rollback
- ✅ Explicit version control

**Best for:** Critical workflows that require explicit approval for any changes.

### Branch References (Not Recommended)

Reference a branch directly:

```yaml
uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@main
```

**Drawbacks:**
- ❌ Unpredictable changes
- ❌ May break without notice
- ❌ No version tracking

**Best for:** Development/testing only, never production.

## Release Process

### 1. Making Changes

When modifying workflows:

1. Create a feature branch
2. Make changes
3. Test thoroughly
4. Create pull request
5. Review and merge to `main`

### 2. Releases are automatic

Merging to `main` is the release. Once the `Test` workflow passes on the merged commit, `Release`
(`.github/workflows/release.yml`, [release-workflow.md](release-workflow.md)) reads the conventional
commit subjects since the last tag and, when they call for it, creates the annotated tag (`v1.2.4`,
`v1.3.0`, `v2.0.0`), moves the major pointer (`v1`, or starts `v2`) and publishes the GitHub release
with the changelog. The pull request's title (or the single commit's subject) decides: `fix:` patch,
`feat:` minor, `feat!:` or a `BREAKING CHANGE:` footer major; `docs:`, `ci:`, `chore:` none.

Nothing is tagged by hand: a hand-made tag is a version the workflow then skips or collides with.
A release that stopped halfway is finished with "Re-run failed jobs" on its run.

## Release Notes Template

```markdown
## v1.2.3 - 2026-02-06

### 🐛 Bug Fixes
- Fixed Docker image cleanup issue on homelab runners
- Resolved git tag push failures with special characters

### 📚 Documentation
- Updated troubleshooting section
- Added example for multi-service builds

### 🔧 Maintenance
- Updated actions/checkout to v4.2.0
- Improved error messages
```

## Breaking Changes

### What Constitutes a Breaking Change?

Changes that require users to modify their workflows:

- ❌ Removing workflow inputs
- ❌ Changing input types or validation
- ❌ Removing workflow outputs
- ❌ Changing output formats
- ❌ Modifying required permissions
- ❌ Changing default behavior significantly

### How to Handle Breaking Changes

1. **Document the change:**
   ```markdown
   ## Breaking Changes

   ### Removed `registry_url` input

   The `registry_url` input has been removed. Use organization variable `REGISTRY_URL` instead.

   **Before:**
   ```yaml
   with:
     registry_url: "rg.fr-par.scw.cloud/integrosa"
   ```

   **After:**
   ```yaml
   # Set REGISTRY_URL as organization variable
   # No workflow changes needed
   ```
   ```

2. **Create migration guide:**
   - Document old vs new approach
   - Provide code examples
   - List all affected workflows
   - Set migration deadline

3. **Bump major version:** title the pull request `feat!: ...` (or add a `BREAKING CHANGE:` footer);
   the release workflow tags `v2.0.0` and starts `v2`.

4. **Notify users:**
   - Post in organization discussions
   - Update documentation
   - Send notification to affected projects

## Deprecation Policy

Before removing features:

1. **Announce deprecation:**
   - Add warning to documentation
   - Update release notes
   - Notify users

2. **Deprecation period:**
   - Minimum 90 days notice
   - Feature still works but logs warnings

3. **Remove in next major version:**
   - Remove deprecated feature
   - Update documentation
   - Provide migration guide

**Example deprecation notice:**

```yaml
# DEPRECATED: registry_url input will be removed in v2.0.0
# Please configure REGISTRY_URL as organization variable instead
# See: https://github.com/Integrosa/.github/docs/migration-v2.md
```

## Version History

### v1.0.0 - Initial Release (2026-02-06)

**Features:**
- Docker build workflow with semantic versioning
- Scaleway Container Registry integration
- Automatic git tagging
- Configurable inputs for flexibility

**Workflows:**
- `reusable-docker-build.yml`

### Future Versions

**v1.1.0 (Planned):**
- Add npm CI workflow
- Enhance Docker build with cache
- Add security scanning integration

**v2.0.0 (Planned):**
- Redesigned input structure
- Support for multiple registries
- Enhanced error handling

## Migration Guides

### Migrating from Repository-Local Workflows

If your project has local workflow files that should use the organization reusable workflow:

**Before:**
```yaml
jobs:
  build:
    uses: ./.github/workflows/docker-build.yml
    with:
      project_name: "my-app"
```

**After:**
```yaml
jobs:
  build:
    uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
    with:
      organization_name: "integrosa"
      project_name: "my-app"
```

**Steps:**
1. Update workflow file
2. Remove local workflow file (optional, can keep for local dev)
3. Test workflow
4. Commit and push

### Migrating Between Major Versions

When a new major version is released, follow these steps:

1. **Review breaking changes:**
   - Read release notes
   - Check migration guide
   - Identify affected workflows

2. **Test in development:**
   ```yaml
   # Test with new version
   uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v2
   ```

3. **Update workflows:**
   - Make required changes
   - Test thoroughly
   - Deploy to production

4. **Monitor:**
   - Watch for errors
   - Verify outputs
   - Check deployments

## Best Practices

### For Workflow Maintainers

1. **Semantic commits:**
   - Use conventional commits
   - Clear commit messages
   - Reference issues

2. **Testing:**
   - Test all changes
   - Verify backward compatibility
   - Document breaking changes

3. **Documentation:**
   - Update docs with code
   - Provide examples
   - Maintain changelog

### For Workflow Users

1. **Use major version tags:**
   ```yaml
   uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
   ```

2. **Review release notes:**
   - Subscribe to releases
   - Check for breaking changes
   - Plan migrations

3. **Pin critical workflows:**
   ```yaml
   # For production-critical workflows
   uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1.2.3
   ```

## Versioning Checklist

When creating a new release:

- [ ] All changes tested
- [ ] Documentation updated
- [ ] Examples updated
- [ ] Breaking changes documented
- [ ] Migration guide created (if major version)
- [ ] Pull request title is a conventional commit with the intended bump (`fix:`, `feat:`, `feat!:`)
- [ ] `Release` run after the merge: tag, major pointer and GitHub release present
- [ ] Users notified (if breaking changes)

## Related Documentation

- [Docker Build Workflow](docker-build-workflow.md)
- [Organization Setup](organization-setup.md)
- [Contributing Guidelines](../CONTRIBUTING.md)
- [Semantic Versioning](https://semver.org/)

---

[← Back to Main README](../README.md)
