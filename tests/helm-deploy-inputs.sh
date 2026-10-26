#!/usr/bin/env bash
# Runs the "Check inputs" step of reusable-helm-deploy.yml (extracted with yq) against good and bad
# inputs; checks the exit code and the arguments it writes to $RUNNER_TEMP/set-args (--set-string, and --values for
# values_file), which helm template and helm upgrade both read.
# Needs bash, jq and yq v4 (mikefarah).
set -uo pipefail
cd "$(dirname "$0")/.."
wf=.github/workflows/reusable-helm-deploy.yml
script=$(yq -e '.jobs.deploy.steps[] | select(.name == "Check inputs") | .run' "$wf") || { echo "no Check inputs step"; exit 1; }
fail=0
ARGS=
run() { # run <expect 0|1> <name>; inputs in IMAGES IMAGE_REPOSITORY IMAGE_DIGEST TIMEOUT VF (values_file); VF_MAKE
  # creates that file in the chart, VF_DIR that directory; LINK=<path> puts a symlink to a file outside the chart at
  # chart/<path> (LINK_DIR=1: to a directory outside, LINK_DANGLING=1: to nothing), CHART_LINK=1 makes the chart
  # directory itself a symlink (the chart then lives in real-chart/), PARENT_LINK=1 puts the chart under deploy/ ->
  # real/ (use CP=deploy/chart). The step's stderr is left in ERR.
  local tmp rc
  tmp=$(mktemp -d); mkdir -p "$tmp/chart"; touch "$tmp/chart/Chart.yaml"
  if [ -n "${VF_MAKE:-}" ]; then mkdir -p "$(dirname "$tmp/chart/$VF_MAKE")"; touch "$tmp/chart/$VF_MAKE"; fi
  if [ -n "${VF_DIR:-}" ]; then mkdir -p "$tmp/chart/$VF_DIR"; fi
  if [ -n "${LINK:-}" ]; then
    echo secret > "$tmp/outside.txt"; mkdir -p "$tmp/outside-dir" "$(dirname "$tmp/chart/$LINK")"
    target="$tmp/outside.txt"; [ -z "${LINK_DIR:-}" ] || target="$tmp/outside-dir"; [ -z "${LINK_DANGLING:-}" ] || target="$tmp/nothing"
    ln -s "$target" "$tmp/chart/$LINK"
  fi
  if [ -n "${CHART_LINK:-}" ]; then mv "$tmp/chart" "$tmp/real-chart"; ln -s real-chart "$tmp/chart"; fi
  if [ -n "${PARENT_LINK:-}" ]; then mkdir -p "$tmp/real"; mv "$tmp/chart" "$tmp/real/chart"; ln -s real "$tmp/deploy"; fi
  ( cd "$tmp" && RUNNER_TEMP="$tmp" NAMESPACE="${NS:-b3net-staging}" RELEASE="${REL:-medusa}" CHART_PATH="${CP:-chart}" \
      IMAGES="${IMAGES:-}" IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-}" IMAGE_DIGEST="${IMAGE_DIGEST:-}" TIMEOUT="${TIMEOUT:-5m}" \
      VALUES_FILE="${VF:-}" APP_VERSION="${AV:-}" \
      bash -c "$script" >/dev/null 2>"$tmp/stderr" ); rc=$?
  ERR=$(cat "$tmp/stderr" 2>/dev/null)
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
# values_file: a file inside chart_path, passed as --values to helm template and helm upgrade (both read set-args).
VFA=$'--set-string\nimage.repository='"$R"$'\n--set-string\nimage.digest='"$D"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D VF=values-prod.yaml VF_MAKE=values-prod.yaml run 0 "values_file in the chart"
if [ "$ARGS" = "$VFA"$'\n--values\nchart/values-prod.yaml' ]; then echo "ok   values_file args"; else echo "FAIL values_file args: $ARGS"; fail=1; fi
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D VF=env/prod.yaml VF_MAKE=env/prod.yaml run 0 "values_file in a chart subdirectory"
if [ "$ARGS" = "$VFA"$'\n--values\nchart/env/prod.yaml' ]; then echo "ok   values_file subdirectory args"; else echo "FAIL values_file subdirectory args: $ARGS"; fail=1; fi
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D VF=missing.yaml run 1 "values_file that does not exist"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D VF=../values.yaml run 1 "values_file with .."
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D VF=env/../../x.yaml VF_MAKE=env/x.yaml run 1 "values_file escaping through .."
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D VF=/etc/hosts run 1 "absolute values_file"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D VF=-values.yaml VF_MAKE=./-values.yaml run 1 "values_file starting with -"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D VF=env VF_DIR=env run 1 "values_file that is a directory"
# Helm loads these directories of a chart as templates, CRDs and subcharts: a values file there would be rendered too.
for d in templates crds charts; do
  IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D VF=$d/prod.yaml VF_MAKE=$d/prod.yaml run 1 "values_file in $d/"
done
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D VF=env/templates/prod.yaml VF_MAKE=env/templates/prod.yaml run 0 "values_file in a nested templates/ (not Helm's)"
IMAGES="{\"backend\":{\"repository\":\"$R\",\"digest\":\"$D\"}}" VF=values-prod.yaml VF_MAKE=values-prod.yaml run 0 "images with values_file"
if [ "$(tail -2 <<<"$ARGS")" = $'--values\nchart/values-prod.yaml' ] && grep -qx -- "images.backend.digest=$D" <<<"$ARGS"; then echo "ok   images with values_file args"; else echo "FAIL images with values_file args: $ARGS"; fail=1; fi
# No symlink anywhere in the chart, nor as the chart directory: Helm follows them (.Files.Get, --values), so a committed
# symlink could read any file on the runner, /proc/self/environ with the job's tokens included, into the release.
err_says() { # err_says <name> <text>: the last run failed for this reason, not another one
  if grep -qF -- "$2" <<<"$ERR"; then echo "ok   $1: refused by the symlink check"; else echo "FAIL $1: stderr was: $ERR"; fail=1; fi
}
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D LINK=link.txt run 1 "symlink in the chart"; err_says "symlink in the chart" "must not contain symlinks"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D LINK=files/deep/link.txt run 1 "symlink deep in the chart"; err_says "symlink deep in the chart" "must not contain symlinks"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D LINK=files LINK_DIR=1 run 1 "symlink to a directory in the chart"; err_says "symlink to a directory" "must not contain symlinks"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D LINK=gone.txt LINK_DANGLING=1 run 1 "dangling symlink in the chart"; err_says "dangling symlink" "must not contain symlinks"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D LINK=values-prod.yaml VF=values-prod.yaml run 1 "values_file that is a symlink"; err_says "values_file symlink" "must not contain symlinks"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D CHART_LINK=1 run 1 "chart directory that is a symlink"; err_says "chart directory symlink" "chart_path must not go through a symlink"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D PARENT_LINK=1 CP=deploy/chart run 1 "chart under a symlinked parent"; err_says "symlinked parent" "chart_path must not go through a symlink"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D VF_MAKE=files/deep/ok.txt run 0 "regular files deep in the chart (control)"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D VF_DIR=sub CP=chart/sub run 1 "chart directory without Chart.yaml"
if grep -qF "no Chart.yaml in chart/sub" <<<"$ERR"; then echo "ok   missing Chart.yaml: its own message"; else echo "FAIL missing Chart.yaml message: $ERR"; fail=1; fi
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D CP=missing run 1 "chart path that does not exist"
if grep -qF "no Chart.yaml in missing" <<<"$ERR"; then echo "ok   missing chart path: its own message"; else echo "FAIL missing chart path message: $ERR"; fail=1; fi
# values_file follows chart_path's path rules: both checks use the same pattern.
if [ "$(grep -c '=~ ^($path_body)\$' <<<"$script")" = 2 ]; then echo "ok   chart_path and values_file share the path pattern"; else echo "FAIL chart_path and values_file do not share path_body"; fail=1; fi
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D VF=$'values.yaml\n--set\nx=y' VF_MAKE=values.yaml run 1 "values_file with a newline"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D VF='values prod.yaml' VF_MAKE='values prod.yaml' run 1 "values_file with a space"
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
# app_version: appended as one --set-string, refused when it is not vX.Y.Z[-pre-release].
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D AV=v1.4.0 run 0 "app_version"
if [ "$(tail -2 <<<"$ARGS")" = $'--set-string\nappVersion=v1.4.0' ]; then echo "ok   app_version args"; else echo "FAIL app_version args: $ARGS"; fail=1; fi
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D AV=v1.4.0-staging.abc1234 run 0 "app_version with a pre-release"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D run 0 "no app_version"
if ! grep -q appVersion <<<"$ARGS"; then echo "ok   no app_version, no argument"; else echo "FAIL argument without app_version: $ARGS"; fail=1; fi
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D AV=1.4.0 run 1 "app_version without v"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D AV='v1.4.0,image.digest=x' run 1 "app_version with a comma"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D AV=$'v1.4.0\n--set\nx=y' run 1 "app_version with a newline"
IMAGES='' IMAGE_REPOSITORY=$R IMAGE_DIGEST=$D AV=v01.4.0 run 1 "app_version with a leading zero"
if yq '.jobs.deploy.runs-on' "$wf" | grep -qF "inputs.cluster == 'integrosa-platform' && vars.CI_RUNNER == 'integrosa-ci'"; then echo "ok   self-hosted runners only for integrosa-platform"; else echo "FAIL runs-on may route b3net-prod to self-hosted runners"; fail=1; fi
if [ "$(yq '.jobs.deploy.concurrency.group' "$wf")" = 'helm-deploy/${{ inputs.cluster }}/${{ inputs.namespace }}/${{ inputs.release }}' ]; then echo "ok   queue per cluster"; else echo "FAIL concurrency group without the cluster"; fail=1; fi
if grep -qF 'audience=$CLUSTER' "$wf" && ! grep -q 'audience=integrosa-platform' "$wf"; then echo "ok   token audience from the selected cluster"; else echo "FAIL token audience is not the selected cluster's"; fail=1; fi
if grep -qF '`b3net-prod`' docs/helm-deploy-workflow.md && grep -qF 'https://5.9.48.90:6443' docs/helm-deploy-workflow.md; then echo "ok   docs list the clusters"; else echo "FAIL docs do not list the clusters"; fail=1; fi
exit $fail
