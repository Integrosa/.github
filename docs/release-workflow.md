# Release Workflow

`reusable-release.yml` releases a repository by itself: for the commit it is given, it reads the
conventional commit subjects since the last tag and, when they call for it, creates the next semantic
version as an annotated tag, moves the major alias (`v1`, `v2`, ...) to it and publishes a GitHub
release with the changelog. Nobody tags by hand.

## Which commits release what

| Commit subject | Release |
|---|---|
| `fix: ...` | patch (`v1.6.0` -> `v1.6.1`) |
| `feat: ...` | minor (`v1.6.1` -> `v1.7.0`) |
| `feat!: ...`, or a `BREAKING CHANGE:` footer | major (`v1.7.0` -> `v2.0.0`, and `v2` starts) |
| `docs:`, `ci:`, `test:`, `chore:`, `refactor:`, ... | none (or a patch with `default_bump: patch`) |

Several commits since the last tag: the largest bump wins.

**What a "commit subject" is after a merge.** With a squash merge, GitHub writes the subject from the
pull request's title, or from the single commit's subject when the pull request has one commit
(`squash_merge_commit_title: COMMIT_OR_PR_TITLE`, the default), and by default it copies every commit
message into the body (`COMMIT_MESSAGES`). The analysis reads bodies too: a `BREAKING CHANGE:` footer
left in any commit of the branch makes a major release, and a `[no-release]` or `[skip-release]`
anywhere in the message removes the commit from the analysis. With a merge commit or a rebase merge,
the branch's own commits are analysed and the title is not. Keep titles and commit messages
conventional, or set the repository to squash with the pull request's title and an empty body.

## Use it

The starter template **Integrosa Release (semantic versioning)** (Actions -> New workflow) writes
this; by hand:

```yaml
name: Release
on:
  push:
    branches: [main]
permissions:
  contents: write
jobs:
  release:
    concurrency: {group: release, cancel-in-progress: false, queue: max}
    uses: Integrosa/.github/.github/workflows/reusable-release.yml@v1
```

The `concurrency` queue matters: without it two quick pushes compute the same version, and the second
run stops with "exists on another commit" ('Re-run all jobs' then computes the next one). `queue: max`
keeps every waiting run; GitHub's default cancels a pending one when another queues.

To release only tested commits, trigger it from the test workflow instead and pass the tested commit,
as this repository does (`.github/workflows/release.yml`):

```yaml
on:
  workflow_run:
    workflows: [Test]
    types: [completed]
    branches: [main]
jobs:
  release:
    if: github.event.workflow_run.conclusion == 'success' && github.event.workflow_run.event == 'push'
    concurrency: {group: release, cancel-in-progress: false, queue: max}
    uses: Integrosa/.github/.github/workflows/reusable-release.yml@v1
    with:
      sha: ${{ github.event.workflow_run.head_sha }}
```

**The first run** analyses the whole history if the repository has no tag with the prefix yet, so an
old `feat!:` makes the first release `v1.0.0`. In a repository already tagged (for example by
`reusable-docker-build`, see below), it continues from the highest tag with the prefix.

## Apps with a Docker build: one tag owner

`reusable-docker-build` has always counted its own version and tagged `v<x.y.z>` on every build
(`push_git_tag`, default true). Two mechanisms tagging the same prefix in one repository race for the
same numbers, so `reusable-release` refuses to run when the caller's workflows contain a
`reusable-docker-build` job that tags with the same prefix (step "One tag owner per prefix"): unless
its `push_git_tag` is a literal `false`, a build job counts as tagging, also with `version_tag`, because
an empty `version_tag` falls back to the build's own count and tag. Three ways to combine them:

1. **Version once, here, and build that version** (for apps that want release notes):
   ```yaml
   jobs:
     release:
       concurrency: {group: release, cancel-in-progress: false, queue: max}
       uses: Integrosa/.github/.github/workflows/reusable-release.yml@v1
       with:
         default_bump: patch   # every push gets a version, as the build has always given it
     build:
       needs: release
       if: needs.release.outputs.new_tag != ''
       uses: Integrosa/.github/.github/workflows/reusable-docker-build.yml@v1
       with:
         organization_name: integrosa
         project_name: my-app
         version_tag: ${{ needs.release.outputs.new_tag }}
         git_ref: ${{ needs.release.outputs.sha }}
         push_git_tag: false
       secrets: inherit
   ```
   The build counts nothing and tags nothing: it builds the released commit (`git_ref`, required with
   `version_tag`) and labels it with that version. A repeated run of an older release builds nothing,
   so `:latest` and a deploy after it never go back to an older version. A run that releases nothing (every commit marked `[skip-release]`) builds
   nothing.
2. Keep the build's own tagging and do not use `reusable-release` (the apps today).
3. Give the two different prefixes (`tag_prefix: image-v` on the build), if both kinds of tags are
   wanted. The release reads only `<its prefix>X.Y.Z` (`prefix_match_tag`), so `v1.2.3` is never read as
   version 1.2.3 under an empty or another prefix. The check also finds a build called locally
   (`./.github/workflows/reusable-docker-build.yml`).

## Inputs

| Input | Default | Meaning |
|---|---|---|
| `tag_prefix` | `v` | prefix of the version tags (letters, digits, `.`, `-`, `_`) |
| `release_branch` | `main` | the commit to release must be on this branch |
| `sha` | the triggering commit | the commit to release (full id); a caller gated on its tests passes the tested one |
| `default_bump` | `false` | `false`: commits that ask for no release make none; `patch`: every run releases |
| `major_alias` | `true` | move `<prefix><major>` (e.g. `v1`) to every new release |
| `github_release` | `true` | publish a GitHub release with the changelog |

Outputs: `new_tag`, the version tag of this run (or the one already on the commit when a run is
repeated), empty when nothing was released; `sha`, the commit released.

## How it works, and its limits

- **Two jobs.** `version` (token: read-only) checks the inputs and that the commit is on the release
  branch, runs the tag-owner check, and runs
  [`mathieudutour/github-tag-action`](https://github.com/mathieudutour/github-tag-action) v7.0.0 (pinned
  by commit, `dry_run: true`): it only computes the version and the changelog, with semantic-release's
  commit analyzer and the `conventionalcommits` preset; the release branch is passed to it as `ref`,
  so a run from another event or branch never computes a preview version, and only a plain
  `<prefix>X.Y.Z` is ever published. `publish` (token: `contents: write`, only this
  repository's own steps) creates the annotated tag and moves the alias through the GitHub API, then
  publishes the release. The third-party code never holds a write token.
- **Idempotent `publish`.** A tag already on the commit is left alone, a version tag on another commit
  stops the job, and the alias only moves forward (never back to an older release, e.g. a late run);
  an alias on a commit outside the release's history stops the job (move it by hand once). Only a
  "not found" from the API means a tag is absent; any other API error stops the job.
  A release that stopped halfway (an API error) is finished by running it again, with either re-run
  button: a repeated run finds the version tag already on its commit and finishes the alias and the
  release notes (generated by GitHub when the run has no changelog of its own). A repeated run of an
  older release does nothing.
- **Queued.** `publish` runs one at a time per repository with `queue: max`; the caller queues whole
  runs (above), so versions are computed in order.
- **Not confirmed before the first real run:** whether creating tags on commits that change
  `.github/workflows/*` with the workflow's `GITHUB_TOKEN` needs the `workflows` permission, which that
  token cannot have (the action's README warns about it for older commits). If the first release of
  this repository fails there, the fix is a GitHub App token for `publish`; this page then says so.
- Tags created with the workflow's `GITHUB_TOKEN` do not start other workflows (GitHub's rule against
  recursive runs); a workflow that should run on a new tag needs another trigger.

Tests without GitHub, all in the `Test` workflow: `tests/release-guard.sh` (the tag-owner check against
example callers), `tests/release-publish.sh` (the tagging step against a fake `gh`) and
`tests/release-version.sh` (the choice of the version to publish, in a scratch git repository).
