#!/usr/bin/env bash
# Runs the "Check inputs" step of reusable-helm-deploy.yml (extracted with yq) against good and bad
# inputs; checks the exit code and the --set-string arguments it writes to $RUNNER_TEMP/set-args.
# Needs bash, jq and yq v4 (mikefarah).
set -uo pipefail
cd "$(dirname "$0")/.."
wf=.github/workflows/reusable-helm-deploy.yml
script=$(yq -e '.jobs.deploy.steps[] | select(.name == "Check inputs") | .run' "$wf") || { echo "no Check inputs step"; exit 1; }
fail=0
ARGS=
run() { # run <expect 0|1> <name>; inputs in IMAGES IMAGE_REPOSITORY IMAGE_DIGEST TIMEOUT
  local tmp rc
  tmp=$(mktemp -d); mkdir -p "$tmp/chart"; touch "$tmp/chart/Chart.yaml"
  ( cd "$tmp" && RUNNER_TEMP="$tmp" NAMESPACE="${NS:-b3net-staging}" RELEASE="${REL:-medusa}" CHART_PATH="${CP:-chart}" \
      IMAGES="${IMAGES:-}" IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-}" IMAGE_DIGEST="${IMAGE_DIGEST:-}" TIMEOUT="${TIMEOUT:-5m}" \
      bash -c "$script" >/dev/null 2>&1 ); rc=$?
  if { [ "$1" = 0 ] && [ "$rc" = 0 ]; } || { [ "$1" = 1 ] && [ "$rc" != 0 ]; }; then echo "ok   $2"; else echo "FAIL $2 (exit $rc)"; fail=1; fi
  ARGS=$(cat "$tmp/set-args" 2>/dev/null); rm -rf "$tmp"
  if [ "$rc" = 0 ] && [ -z "$ARGS" ]; then echo "FAIL $2: success without arguments"; fail=1; fi
}
D=sha256:$(printf 'a%.0s' {1..64}); R=rg.pl-waw.scw.cloud/b3net/backend
# Old interface: the arguments are the ones the workflow passed before the images input existed.
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D run 0 "old interface"
if [ "$ARGS" = $'--set-string\nimage.repository='"$R"$'\n--set-string\nimage.digest='"$D" ]; then echo "ok   old interface args"; else echo "FAIL old interface args: $ARGS"; fail=1; fi
# New interface.
IMAGES="{\"backend\":{\"repository\":\"$R\",\"digest\":\"$D\"},\"storefront\":{\"repository\":\"$R-sf\",\"digest\":\"$D\"}}" run 0 "two images"
if grep -qx -- "images.backend.digest=$D" <<<"$ARGS" && grep -qx -- "images.storefront.repository=$R-sf" <<<"$ARGS" && [ "$(grep -cx -- --set-string <<<"$ARGS")" = 4 ]; then echo "ok   images args"; else echo "FAIL images args: $ARGS"; fail=1; fi
IMAGES='{}' run 1 "zero images"
IMAGES="{\"a.b\":{\"repository\":\"$R\",\"digest\":\"$D\"}}" run 1 "key with a dot"
IMAGES="{\"a,b=c\":{\"repository\":\"$R\",\"digest\":\"$D\"}}" run 1 "key with comma and equals"
IMAGES="{\"Backend\":{\"repository\":\"$R\",\"digest\":\"$D\"}}" run 1 "key starting upper case"
IMAGES="{\"backend\":{\"repository\":\"$R:1.0\",\"digest\":\"$D\"}}" run 1 "repository with tag"
IMAGES="{\"backend\":{\"repository\":\"$R,x=y\",\"digest\":\"$D\"}}" run 1 "repository with comma"
IMAGES="{\"backend\":{\"repository\":\"$R\",\"digest\":\"sha256:xyz\"}}" run 1 "bad digest"
IMAGES="{\"backend\":{\"repository\":\"$R\"}}" run 1 "missing digest"
IMAGES="{\"backend\":{\"repository\":\"$R\",\"digest\":\"$D\",\"tag\":\"x\"}}" run 1 "extra field"
IMAGES="{\"backend\":{\"repository\":[\"$R\"],\"digest\":\"$D\"}}" run 1 "repository not a string"
IMAGES="{\"backend\\n\":{\"repository\":\"$R\",\"digest\":\"$D\"}}" run 1 "key with a trailing newline"
IMAGES="{\"backend\":{\"repository\":\"$R\\n\",\"digest\":\"$D\"}}" run 1 "repository with a trailing newline"
IMAGES="{\"backend\":{\"repository\":\"$R\",\"digest\":\"$D\\n\"}}" run 1 "digest with a trailing newline"
IMAGES="{\"backend\":{\"repository\":\"$R\\\\\",\"digest\":\"$D\"}}" run 1 "repository with a backslash"
IMAGES='[1]' run 1 "not an object"
IMAGES='  ' run 1 "whitespace only"
IMAGES=$'\n' run 1 "newline only"
O="{\"backend\":{\"repository\":\"$R\",\"digest\":\"$D\"}}"
IMAGES="$O$O" run 1 "two JSON documents"
IMAGES='null' run 1 "null"
IMAGES='not json' run 1 "not JSON"
IMAGES=$(jq -nc --arg r "$R" --arg d "$D" '[range(11)] | map({key: "i\(.)", value: {repository: $r, digest: $d}}) | from_entries') run 1 "eleven images"
IMAGES=$(jq -nc --arg r "$R" --arg d "$D" '[range(10)] | map({key: "i\(.)", value: {repository: $r, digest: $d}}) | from_entries') run 0 "ten images"
IMAGES="{\"backend\":{\"repository\":\"$R\",\"digest\":\"$D\"}}" IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D run 1 "both interfaces"
IMAGES='' IMAGE_REPOSITORY='' IMAGE_DIGEST='' run 1 "no image at all"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST='' run 1 "repository without digest"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D TIMEOUT=11m run 1 "timeout above 10m"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D TIMEOUT=15m run 1 "timeout 15m"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D TIMEOUT=0m run 1 "timeout 0m"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D TIMEOUT=10m run 0 "timeout 10m"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D TIMEOUT='5m --dry-run' run 1 "timeout with a flag"
# The pre-existing checks of the same step: namespace, release and chart path (traversal, flags).
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D CP=../chart run 1 "chart path with .."
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D CP=chart/.. run 1 "chart path ending in .."
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D CP=-chart run 1 "chart path starting with -"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D CP=/chart run 1 "absolute chart path"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D CP=missing run 1 "chart path without Chart.yaml"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D NS='Bad_NS' run 1 "namespace not a DNS label"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D REL='-x' run 1 "release starting with -"
# The test workflow must use the yq the deploy job pins (same URL and checksum).
pin() { grep -oE 'yq/releases/download/v[0-9.]+/yq_linux_amd64|[0-9a-f]{64}  \$RUNNER_TEMP/(bin/)?yq' "$1" | sed 's#  .*##' | sort; }
if [ -n "$(pin "$wf")" ] && [ "$(pin "$wf")" = "$(pin .github/workflows/test.yml)" ]; then echo "ok   test workflow pins the deploy job's yq"; else echo "FAIL test workflow and deploy job pin different yq"; fail=1; fi
exit $fail
