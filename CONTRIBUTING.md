# Contributing to Integrosa Reusable Workflows

Thank you for your interest in contributing! This document provides guidelines for contributing new workflows, improving existing ones, and maintaining high quality standards.

## Table of Contents

- [Getting Started](#getting-started)
- [Workflow Design Principles](#workflow-design-principles)
- [Adding a New Reusable Workflow](#adding-a-new-reusable-workflow)
- [Updating Existing Workflows](#updating-existing-workflows)
- [Documentation Requirements](#documentation-requirements)
- [Testing Guidelines](#testing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Code Review Criteria](#code-review-criteria)

## Getting Started

### Prerequisites

- GitHub account with access to Integrosa organization
- Basic understanding of GitHub Actions
- Familiarity with YAML syntax
- Knowledge of the problem your workflow solves

### Repository Structure

```
.github/
├── .github/workflows/       # Reusable workflows
├── workflow-templates/      # Starter templates
├── examples/               # Usage examples
├── docs/                   # Detailed documentation
└── CONTRIBUTING.md         # This file
```

## Workflow Design Principles

### 1. Keep It Simple

- Focus on one specific task per workflow
- Avoid trying to handle every edge case
- Prefer explicit configuration over magic defaults
- Don't overcomplicate with unnecessary abstraction

### 2. Make It Reusable

- Use `workflow_call` trigger
- Parameterize with inputs
- Provide clear outputs
- Minimize assumptions about repository structure

### 3. Follow Conventions

- Use semantic versioning for releases
- Follow naming conventions
- Consistent parameter naming
- Clear, descriptive names

### 4. Secure by Default

- Never expose secrets in logs
- Use minimal required permissions
- Validate inputs where possible
- Document security implications

### 5. Fail Fast, Fail Clear

- Validate requirements early
- Provide helpful error messages
- Exit with clear status codes
- Log context for debugging

## Adding a New Reusable Workflow

### Step 1: Plan the Workflow

Before writing code, document:

1. **Purpose:** What problem does this solve?
2. **Use cases:** When should users use this?
3. **Inputs:** What configuration is needed?
4. **Outputs:** What information should be provided?
5. **Dependencies:** What tools/actions are required?

**Example:**

```markdown
## npm CI Workflow

**Purpose:** Run tests and build for npm projects

**Use cases:**
- Pull request validation
- Pre-deployment checks
- Automated testing

**Inputs:**
- `node_version`: Node.js version to use
- `install_command`: Custom install command
- `test_command`: Custom test command
- `build_command`: Custom build command

**Outputs:**
- `test_result`: Pass/fail status
- `build_artifacts`: Path to build output

**Dependencies:**
- Node.js
- npm/yarn
```

### Step 2: Create the Workflow File

Create `.github/workflows/reusable-<name>.yml`:

```yaml
name: Reusable <Name>

on:
  workflow_call:
    inputs:
      # Required inputs first
      parameter_name:
        description: "Clear description"
        required: true
        type: string

      # Optional inputs with defaults
      optional_parameter:
        description: "Clear description"
        required: false
        type: string
        default: "sensible-default"

    outputs:
      output_name:
        description: "Clear description of output"
        value: ${{ jobs.job_name.outputs.output_name }}

jobs:
  job_name:
    runs-on: ${{ inputs.runs_on }}
    permissions:
      # Minimal required permissions
      contents: read

    outputs:
      output_name: ${{ steps.step_id.outputs.value }}

    steps:
      - name: Descriptive step name
        run: echo "Implementation"
```

### Step 3: Create Documentation

Create `docs/<workflow-name>.md`:

```markdown
# <Workflow Name> Documentation

## Overview
Brief description of what the workflow does.

## Usage
\`\`\`yaml
jobs:
  job_name:
    uses: Integrosa/.github/.github/workflows/reusable-<name>.yml@v1
    with:
      parameter_name: "value"
\`\`\`

## Inputs
| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| ... | ... | ... | ... | ... |

## Outputs
| Output | Description | Example |
|--------|-------------|---------|
| ... | ... | ... |

## Examples
(Multiple complete examples)

## Troubleshooting
(Common issues and solutions)
```

### Step 4: Create Examples

Create `examples/<workflow-name>-*.yml`:

- `examples/<name>-basic.yml` - Minimal usage
- `examples/<name>-advanced.yml` - Advanced features
- `examples/<name>-integration.yml` - Integration with other workflows

### Step 5: Create Starter Template (Optional)

If the workflow is commonly used, create a starter template:

- `workflow-templates/<name>.yml` - Template workflow
- `workflow-templates/<name>.properties.json` - Template metadata

### Step 6: Update Main README

Add your workflow to the main README.md:

```markdown
### 📦 <Workflow Name>
Brief description of what it does.

**Features:**
- Feature 1
- Feature 2

[View Documentation](docs/<workflow-name>.md)
```

## Updating Existing Workflows

### Non-Breaking Changes

For bug fixes and backward-compatible improvements:

1. Make changes
2. Update documentation
3. Add tests
4. Create PR with title: `fix: <description>` or `chore: <description>`

### Breaking Changes

For changes that require users to modify their workflows:

1. Document the breaking change
2. Create migration guide
3. Update version numbers
4. Create PR with title: `feat!: <description>` or include `BREAKING CHANGE:` in commit body

## Documentation Requirements

Every contribution must include:

### 1. Inline Comments

```yaml
steps:
  # Validate input format before processing
  - name: Validate inputs
    run: |
      # Check if version follows semver pattern
      if [[ ! "${{ inputs.version }}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: version must be in format X.Y.Z"
        exit 1
      fi
```

### 2. Workflow Documentation

- Complete reference in `docs/`
- All inputs documented with examples
- All outputs documented with examples
- Usage examples (basic, advanced, integration)
- Troubleshooting section

### 3. Example Workflows

- At least one basic example
- Advanced example if workflow has complex features
- Integration example if workflow is commonly combined with others

### 4. Updated Main README

- Add/update workflow listing
- Update table of contents if needed
- Update quick start examples if relevant

## Testing Guidelines

### Manual Testing

1. **Create test repository:**
   ```bash
   # Create test repo in organization
   gh repo create Integrosa/test-workflow --private
   ```

2. **Create test workflow:**
   ```yaml
   # .github/workflows/test.yml
   name: Test Workflow

   on: workflow_dispatch

   jobs:
     test:
       uses: Integrosa/.github/.github/workflows/reusable-new-workflow.yml@main
       with:
         parameter: "test-value"
   ```

3. **Run and verify:**
   - Trigger workflow manually
   - Check all steps execute successfully
   - Verify outputs are correct
   - Check logs for errors/warnings

### Testing Checklist

- [ ] Workflow triggers correctly
- [ ] All inputs are properly validated
- [ ] Default values work as expected
- [ ] All outputs are generated correctly
- [ ] Error handling works (test failure scenarios)
- [ ] Permissions are sufficient (but minimal)
- [ ] Secrets are not exposed in logs
- [ ] Workflow completes in reasonable time
- [ ] Clean up resources if applicable

### Test Different Scenarios

Test with:
- Minimal inputs (all defaults)
- Custom inputs
- Edge cases (empty strings, special characters)
- Failure scenarios (missing files, invalid inputs)
- Different runner types (if applicable)

## Pull Request Process

### 1. Create Feature Branch

```bash
git checkout -b feature/add-npm-ci-workflow
# or
git checkout -b fix/docker-build-cleanup
```

### 2. Make Changes

- Follow workflow design principles
- Add/update documentation
- Create examples
- Test thoroughly

### 3. Commit Changes

Use [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Features
git commit -m "feat: add npm CI workflow"

# Bug fixes
git commit -m "fix: resolve Docker cleanup issue"

# Breaking changes
git commit -m "feat!: redesign workflow inputs"

# Documentation
git commit -m "docs: add troubleshooting section"

# Maintenance
git commit -m "chore: update dependencies"
```

### 4. Push and Create PR

```bash
git push origin feature/add-npm-ci-workflow
gh pr create --title "feat: add npm CI workflow" --body "..."
```

### 5. PR Description Template

```markdown
## Description
Brief description of what this PR does.

## Type of Change
- [ ] New reusable workflow
- [ ] Update to existing workflow
- [ ] Bug fix
- [ ] Documentation update
- [ ] Breaking change

## Changes
- Change 1
- Change 2
- Change 3

## Testing
Describe how you tested these changes:
- Test scenario 1
- Test scenario 2

## Documentation
- [ ] Updated workflow documentation
- [ ] Added/updated examples
- [ ] Updated main README
- [ ] Added inline comments

## Checklist
- [ ] Follows workflow design principles
- [ ] All inputs documented
- [ ] All outputs documented
- [ ] Examples provided
- [ ] Tested manually
- [ ] Breaking changes documented (if applicable)
- [ ] Migration guide provided (if applicable)

## Related Issues
Closes #123
```

## Code Review Criteria

PRs will be reviewed for:

### 1. Functionality

- [ ] Workflow solves stated problem
- [ ] Inputs are well-designed
- [ ] Outputs are useful
- [ ] Error handling is robust
- [ ] Edge cases are handled

### 2. Code Quality

- [ ] Follows YAML best practices
- [ ] Clear, descriptive names
- [ ] Appropriate comments
- [ ] No hardcoded values (use inputs)
- [ ] Minimal duplication

### 3. Security

- [ ] Minimal required permissions
- [ ] No secrets in logs
- [ ] Input validation where needed
- [ ] Secure defaults

### 4. Documentation

- [ ] Complete workflow documentation
- [ ] Clear examples
- [ ] Troubleshooting guide
- [ ] Updated main README

### 5. Testing

- [ ] Manually tested
- [ ] Test results documented
- [ ] Examples work correctly

### 6. Versioning

- [ ] Follows semantic versioning
- [ ] Breaking changes documented
- [ ] Migration guide (if breaking)

## Style Guide

### YAML Formatting

```yaml
# Good: consistent indentation, clear structure
name: Reusable Workflow

on:
  workflow_call:
    inputs:
      parameter_name:
        description: "Clear description"
        required: true
        type: string

jobs:
  job_name:
    runs-on: ubuntu-latest
    steps:
      - name: Step name
        run: echo "Command"
```

### Naming Conventions

- **Workflow files:** `reusable-<name>.yml`
- **Jobs:** Descriptive, lowercase with hyphens: `build-and-test`
- **Steps:** Action-oriented, sentence case: `Build Docker image`
- **Inputs:** snake_case: `project_name`
- **Outputs:** snake_case: `version_tag`

### Comments

```yaml
# Section header comment
- name: Step name
  run: |
    # Explain why, not what
    # Good: "Cleanup required before push to avoid conflicts"
    # Bad: "Delete old images"
    docker image prune -f
```

## Getting Help

- **Questions:** Open a [Discussion](https://github.com/Integrosa/.github/discussions)
- **Bugs:** Open an [Issue](https://github.com/Integrosa/.github/issues)
- **Documentation:** Check [docs/](docs/) directory
- **Examples:** Check [examples/](examples/) directory

## Recognition

Contributors will be:
- Listed in release notes
- Mentioned in documentation (if significant contribution)
- Added to CONTRIBUTORS.md (if they wish)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to Integrosa Reusable Workflows! 🎉

[← Back to Main README](README.md)
