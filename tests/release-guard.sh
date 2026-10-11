#!/usr/bin/env bash
# The "One tag owner per prefix" step of reusable-release.yml, run as it is in the workflow against
# example caller repositories: a reusable-docker-build that tags with the same prefix stops the release,
# anything else lets it through. Needs yq (mikefarah v4) and jq, as the runner has them.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
yq -r '.jobs.version.steps[] | select(.name == "One tag owner per prefix") | .run' \
  .github/workflows/reusable-release.yml > "$tmp/guard.sh"
[ -s "$tmp/guard.sh" ] || { echo "FAIL the guard step was not found"; exit 1; }
build='Integrosa/.github/.github/workflows/reusable-docker-build.yml'
fail=0
case_() { # case_ <name> <release tag_prefix> <expected exit> <file name> <workflow yaml>
  local dir="$tmp/$1" rc=0
  mkdir -p "$dir/.github/workflows"
  printf '%s\n' "$5" > "$dir/.github/workflows/$4"
  (cd "$dir" && TAG_PREFIX=$2 bash "$tmp/guard.sh" >/dev/null 2>&1) || rc=$?
  if [ "$rc" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: exit $rc, want $3"; fail=1; fi
}
case_ "build tags v by default: refused" v 1 build.yml "jobs: {build: {uses: $build@main, with: {project_name: x}}}"
case_ "build tags v explicitly, .yaml file: refused" v 1 b.yaml "jobs: {build: {uses: $build@v1, with: {tag_prefix: v, push_git_tag: true}}}"
case_ "build tagging decided by an expression: refused" v 1 build.yml "jobs: {build: {uses: $build@v1, with: {push_git_tag: \"\${{ inputs.tag }}\"}}}"
case_ "build with push_git_tag false: allowed" v 0 build.yml "jobs: {build: {uses: $build@v1, with: {push_git_tag: false}}}"
case_ "build of this workflow's version with push_git_tag false: allowed" v 0 build.yml "jobs: {build: {uses: $build@v1, needs: release, with: {push_git_tag: false, version_tag: \"\${{ needs.release.outputs.new_tag }}\"}}}"
case_ "version_tag without push_git_tag false (an empty one falls back to tagging): refused" v 1 build.yml "jobs: {build: {uses: $build@v1, needs: release, with: {version_tag: \"\${{ needs.release.outputs.new_tag }}\"}}}"
case_ "build prefix from an expression: refused" v 1 build.yml "jobs: {build: {uses: $build@v1, with: {tag_prefix: \"\${{ inputs.prefix }}\"}}}"
case_ "build called locally (./.github/workflows/...): refused" v 1 build.yml "jobs: {build: {uses: ./.github/workflows/reusable-docker-build.yml}}"
case_ "build with another prefix: allowed" v 0 build.yml "jobs: {build: {uses: $build@v1, with: {tag_prefix: image-v}}}"
case_ "release with another prefix: allowed" rel- 0 build.yml "jobs: {build: {uses: $build@main}}"
case_ "no Docker build: allowed" v 0 ci.yml "jobs: {test: {runs-on: ubuntu-latest, steps: [{run: echo}]}}"
# This repository defines reusable-docker-build but calls it nowhere.
rc=0; TAG_PREFIX=v bash "$tmp/guard.sh" >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ]; then echo "ok   this repository: allowed"; else echo "FAIL this repository: exit $rc"; fail=1; fi
exit $fail
