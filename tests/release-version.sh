#!/usr/bin/env bash
# The "Version to publish" step of reusable-release.yml, run as it is in the workflow in a scratch git
# repository: a computed version passes, a repeated run on a tagged commit picks that tag up, a preview
# version is refused, a commit without a version tag publishes nothing. Needs git and yq.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
yq -r '.jobs.version.steps[] | select(.name == "Version to publish") | .run' .github/workflows/reusable-release.yml > "$tmp/step.sh"
[ -s "$tmp/step.sh" ] || { echo "FAIL the step was not found"; exit 1; }
git -C "$tmp" init -q repo && cd "$tmp/repo"
git -c user.name=t -c user.email=t@t commit -q --allow-empty -m one && one=$(git rev-parse HEAD)
git -c user.name=t -c user.email=t@t tag -a v1.4.0 -m x && git tag v1 && git tag image-v9.9.9
git -c user.name=t -c user.email=t@t commit -q --allow-empty -m two && two=$(git rev-parse HEAD)
fail=0
check() { # check <name> <NEW_TAG> <SHA> <prefix> <expected tag or "error">
  local out="$tmp/out" rc=0; : > "$out"
  GITHUB_OUTPUT=$out NEW_TAG=$2 SHA=$3 TAG_PREFIX=$4 bash "$tmp/step.sh" >/dev/null 2>&1 || rc=$?
  local got; if [ $rc -ne 0 ]; then got=error; else got=$(sed -n 's/^tag=//p' "$out"); fi
  if [ "$got" = "$5" ]; then echo "ok   $1"; else echo "FAIL $1: got '$got', want '$5'"; fail=1; fi
}
check "computed version" v1.5.0 "$two" v v1.5.0
check "repeated run on the newest release: its version tag (not the alias, not another prefix)" "" "$one" v v1.4.0
check "preview version: refused" v1.5.0-abc1234 "$two" v error
check "untagged commit, nothing computed: nothing" "" "$two" v ""
check "other prefix picks its own tag" "" "$one" image-v image-v9.9.9
git -c user.name=t -c user.email=t@t tag -a v1.5.0 -m x "$two"
check "repeated run of an older release (v1.4.0 while v1.5.0 exists): nothing" "" "$one" v ""
exit $fail
