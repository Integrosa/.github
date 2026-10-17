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
# The docs table states the rules the step enforces (the input description points to the docs).
nb=$(sed -n "s/^ *name_body='\(.*\)'$/\1/p" <<<"$script"); mx=$(sed -n 's/^ *max_images=\([0-9]*\)$/\1/p' <<<"$script")
if [ -n "$nb" ] && [ -n "$mx" ] && grep -qF "1-$mx entries, name \`^$nb\$\`" docs/helm-deploy-workflow.md; then echo "ok   docs state the step's image rules"; else echo "FAIL docs and step disagree on the image rules (name '$nb', max '$mx')"; fail=1; fi
# The test workflow must use the yq the deploy job pins (same URL and checksum).
pin() { grep -oE 'yq/releases/download/v[0-9.]+/yq_linux_amd64|[0-9a-f]{64}  \$RUNNER_TEMP/(bin/)?yq' "$1" | sed 's#  .*##' | sort; }
if [ -n "$(pin "$wf")" ] && [ "$(pin "$wf")" = "$(pin .github/workflows/test.yml)" ]; then echo "ok   test workflow pins the deploy job's yq"; else echo "FAIL test workflow and deploy job pin different yq"; fail=1; fi
if [ -n "$(pin "$wf")" ] && [ "$(pin "$wf")" = "$(pin .github/workflows/cross-audience.yml)" ]; then echo "ok   cross-audience workflow pins the deploy job's yq"; else echo "FAIL cross-audience workflow and deploy job pin different yq"; fail=1; fi
# Select cluster (integrosa_platform ADR 0054): a closed list, each value with its API address, CA and audience fixed
# in the workflow; any other value fails before a token is requested and writes nothing.
sel=$(yq -e '.jobs.deploy.steps[] | select(.name == "Select cluster") | .run' "$wf" 2>/dev/null) || { echo "FAIL no Select cluster step"; exit 1; }
INTEGROSA_CA=$(yq -e '.jobs.deploy.env.API_CA' "$wf" 2>/dev/null); B3NET_CA=$(yq -e '.jobs.deploy.env.B3NET_API_CA' "$wf" 2>/dev/null)
SEL_ENV=; SEL_FP=
select_cluster() { # select_cluster <expect 0|1> <name> <cluster>; leaves the env file in SEL_ENV and the SHA-256 of every
  # certificate of the CA file, one per line, in SEL_FP (a dropped, added or broken certificate changes it)
  local tmp rc
  tmp=$(mktemp -d)
  ( RUNNER_TEMP="$tmp" GITHUB_ENV="$tmp/env" CLUSTER="$3" API_CA="$INTEGROSA_CA" B3NET_API_CA="$B3NET_CA" \
      bash -c "$sel" >/dev/null 2>&1 ); rc=$?
  # The runner does not expand variables in $GITHUB_ENV, so a path must be written expanded: show it as <tmp>.
  SEL_ENV=$(sed "s#$tmp#<tmp>#g" "$tmp/env" 2>/dev/null)
  # One file per certificate, then the fingerprint of each: "openssl x509" alone reads only the first.
  awk -v d="$tmp" '/BEGIN CERTIFICATE/{n++} n{print > (d "/cert" n ".pem")}' "$tmp/api-ca.pem" 2>/dev/null
  SEL_FP=$(for c in "$tmp"/cert*.pem; do [ -f "$c" ] && openssl x509 -in "$c" -noout -fingerprint -sha256 | cut -d= -f2; done 2>/dev/null)
  if [ "$1" = 0 ] && [ "$rc" = 0 ]; then echo "ok   $2"
  elif [ "$1" = 1 ] && [ "$rc" != 0 ] && [ -z "$SEL_ENV" ]; then echo "ok   $2"
  else echo "FAIL $2 (exit $rc, env '$SEL_ENV')"; fail=1; fi
  rm -rf "$tmp"
}
expect_env() { # expect_env <name> <exact env file>
  if [ "$SEL_ENV" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1: $SEL_ENV"; fail=1; fi
}
expect_fp() { # expect_fp <name> <sha256 of each certificate, one per line>
  if [ "$SEL_FP" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1: '$SEL_FP'"; fail=1; fi
}
select_cluster 0 "cluster integrosa-platform" integrosa-platform
expect_env "integrosa-platform values" "API_SERVER=https://194.163.128.14:6443
API_CA_FILE=<tmp>/api-ca.pem"
# The whole chain (server, intermediate, root), as integrosa_platform docs/runbooks/host.md requires it pinned.
expect_fp "integrosa-platform CA chain" "4C:F3:3A:BB:A1:F3:14:66:ED:0E:7B:D4:5D:7C:72:C6:F3:7F:12:27:AA:8A:58:98:73:04:AC:7F:20:C1:FB:1F
AB:CC:D4:A2:E2:5C:05:38:0C:70:5A:B7:4A:6A:65:A0:C3:2E:01:4D:4B:DC:94:9D:CC:53:40:93:AE:0A:A5:35
C7:C5:A5:94:E7:C6:AF:D2:E6:33:8F:25:6F:1D:F7:6E:8A:24:AC:C4:7A:AE:3F:22:82:B5:03:40:BA:6F:3C:51"
select_cluster 0 "cluster b3net-prod" b3net-prod
expect_env "b3net-prod values" "API_SERVER=https://5.9.48.90:6443
API_CA_FILE=<tmp>/api-ca.pem"
expect_fp "b3net-prod CA" 1C:41:CD:A3:8F:6B:B6:AF:87:75:04:0D:DA:9F:23:67:61:E7:02:E4:7F:30:0E:34:40:53:2D:A9:5B:3E:81:DD
select_cluster 1 "cluster empty (a caller passing an unset variable)" ''
select_cluster 1 "cluster upper case" B3NET-PROD
select_cluster 1 "cluster with a trailing space" 'b3net-prod '
select_cluster 1 "cluster with a trailing newline" $'b3net-prod\n'
select_cluster 1 "unknown cluster" x
select_cluster 1 "cluster as an address" https://evil:6443
# The structure around it: the default, the step order, the runner, the queue and the token's audience.
if [ "$(yq '.on.workflow_call.inputs.cluster.default' "$wf")" = integrosa-platform ]; then echo "ok   cluster defaults to integrosa-platform"; else echo "FAIL cluster default"; fail=1; fi
order=$(yq '[.jobs.deploy.steps[] | .name] as $n | [.jobs.deploy.steps | to_entries[] | select(.value.name != "Select cluster" and ((.value.run // "") | test("ACTIONS_ID_TOKEN|API_SERVER|API_CA_FILE|KUBECONFIG|token\\.sh|kubectl |helm (upgrade|history|status)"))) | .key] | map(. > ($n | to_entries[] | select(.value == "Select cluster") | .key)) | all' "$wf")
if [ "$order" = true ]; then echo "ok   Select cluster runs before every step that uses the cluster"; else echo "FAIL a step uses the cluster before Select cluster"; fail=1; fi
# runs-on is an Actions expression: the text must offer self-hosted runners to integrosa-platform only, because
# the b3net-prod API accepts only runner_environment github-hosted (b3net-bare-metal-iac ADR 0017).
if yq '.jobs.deploy.runs-on' "$wf" | grep -qF "inputs.cluster == 'integrosa-platform' && vars.CI_RUNNER == 'integrosa-ci'"; then echo "ok   self-hosted runners only for integrosa-platform"; else echo "FAIL runs-on may route b3net-prod to self-hosted runners"; fail=1; fi
if [ "$(yq '.jobs.deploy.concurrency.group' "$wf")" = 'helm-deploy/${{ inputs.cluster }}/${{ inputs.namespace }}/${{ inputs.release }}' ]; then echo "ok   queue per cluster"; else echo "FAIL concurrency group without the cluster"; fail=1; fi
if grep -qF 'audience=$CLUSTER' "$wf" && ! grep -q 'audience=integrosa-platform' "$wf"; then echo "ok   token audience from the selected cluster"; else echo "FAIL token audience is not the selected cluster's"; fail=1; fi
if grep -qF '`b3net-prod`' docs/helm-deploy-workflow.md && grep -qF 'https://5.9.48.90:6443' docs/helm-deploy-workflow.md; then echo "ok   docs list the clusters"; else echo "FAIL docs do not list the clusters"; fail=1; fi
exit $fail
