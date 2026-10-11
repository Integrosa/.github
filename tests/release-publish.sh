#!/usr/bin/env bash
# The "Tag the release" step of reusable-release.yml, run as it is in the workflow against a fake `gh`
# that keeps refs and tag objects in files: a new release tags and moves the alias, a re-run changes
# nothing, an existing version tag on another commit stops, the alias may move. Needs yq and jq.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
yq -r '.jobs.publish.steps[] | select(.name == "Tag the release") | .run' .github/workflows/reusable-release.yml \
  | sed 's/\${{ inputs.major_alias }}/true/' > "$tmp/step.sh"
[ -s "$tmp/step.sh" ] || { echo "FAIL the publish step was not found"; exit 1; }
mkdir -p "$tmp/bin" "$tmp/state/refs" "$tmp/state/objs"
cat > "$tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
# Fake `gh api` for the step: git/ref/tags/<n> (read), git/tags (create, read), git/refs (create, patch).
set -euo pipefail
st=$STATE; method=GET; path=; jq_expr=; f_object=; f_ref=; f_sha=
args=("$@"); i=1
while [ $i -lt ${#args[@]} ]; do a=${args[$i]}
  case $a in
    -X) method=${args[$((i+1))]}; i=$((i+2));;
    -f|-F) kv=${args[$((i+1))]}; case ${kv%%=*} in object) f_object=${kv#*=};; ref) f_ref=${kv#*=};; sha) f_sha=${kv#*=};; esac
      [ "$method" = GET ] && method=POST; i=$((i+2));;
    --jq) jq_expr=${args[$((i+1))]}; i=$((i+2));;
    *) path=$a; i=$((i+1));;
  esac
done
out() { if [ -n "$jq_expr" ]; then jq -r "$jq_expr"; else cat; fi; }
echo "$method $path" >> "$st/calls"
case "$method $path" in
  "GET repos/o/r/git/ref/tags/"*) n=${path##*/}
    [ ! -f "$st/fail-read" ] || { echo "gh: Server Error (HTTP 502)" >&2; exit 1; }
    [ -f "$st/refs/$n" ] || { echo "gh: Not Found (HTTP 404)" >&2; exit 1; }; v=$(cat "$st/refs/$n")
    # A lightweight ref names the commit itself (prefix "commit:" in the fake's state).
    if [ "${v#commit:}" != "$v" ]; then jq -n --arg s "${v#commit:}" '{object: {type: "commit", sha: $s}}' | out
    else jq -n --arg s "$v" '{object: {type: "tag", sha: $s}}' | out; fi;;
  "GET repos/o/r/compare/"*) r=${path#repos/o/r/compare/}; base=${r%...*}; head=${r#*...}
    # Commits are ordered by their letter: aaaa < bbbb < cccc; dddd is off that history.
    if [ "$head" = "$base" ]; then st_=identical; elif [ "${base:0:1}" = d ] || [ "${head:0:1}" = d ]; then st_=diverged
    elif [[ "$head" > "$base" ]]; then st_=ahead; else st_=behind; fi
    jq -n --arg s "$st_" '{status: $s}' | out;;
  "GET repos/o/r/git/tags/"*) jq -n --arg c "$(cat "$st/objs/${path##*/}")" '{object: {sha: $c}}' | out;;
  "POST repos/o/r/git/tags") id=obj$RANDOM$RANDOM; printf '%s' "$f_object" > "$st/objs/$id"; jq -n --arg s "$id" '{sha: $s}' | out;;
  "POST repos/o/r/git/refs") n=${f_ref#refs/tags/}; [ ! -f "$st/refs/$n" ] || exit 1; printf '%s' "$f_sha" > "$st/refs/$n";;
  "PATCH repos/o/r/git/refs/tags/"*) printf '%s' "$f_sha" > "$st/refs/${path##*/}";;
  *) echo "unexpected: $method $path" >&2; exit 2;;
esac
GH
chmod +x "$tmp/bin/gh"
fail=0
commit_of() { local o; o=$(cat "$tmp/state/refs/$1" 2>/dev/null) || { echo none; return; }
  if [ "${o#commit:}" != "$o" ]; then echo "${o#commit:}"; else cat "$tmp/state/objs/$o"; fi; }
run() { # run <tag> <sha>: exit code of the step
  PATH="$tmp/bin:$PATH" STATE="$tmp/state" REPO=o/r TAG=$1 SHA=$2 TAG_PREFIX=v bash "$tmp/step.sh" >/dev/null 2>&1
}
expect() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
A=$(printf 'a%.0s' {1..40}); B=$(printf 'b%.0s' {1..40}); C=$(printf 'c%.0s' {1..40})
run v1.6.0 "$A"; expect "first release: v1.6.0 and v1 on its commit" '[ "$(commit_of v1.6.0)" = "$A" ] && [ "$(commit_of v1)" = "$A" ]'
run v1.7.0 "$B"; expect "next release: v1.7.0 created, v1 moved" '[ "$(commit_of v1.7.0)" = "$B" ] && [ "$(commit_of v1)" = "$B" ] && [ "$(commit_of v1.6.0)" = "$A" ]'
: > "$tmp/state/calls"; rc=0; run v1.7.0 "$B" || rc=$?
expect "re-run of the same release: no write" '[ $rc -eq 0 ] && ! grep -qE "^(POST|PATCH)" "$tmp/state/calls"'
rc=0; run v1.7.0 "$C" || rc=$?
expect "version tag already on another commit: stops, not moved" '[ $rc -ne 0 ] && [ "$(commit_of v1.7.0)" = "$B" ]'
run v2.0.0 "$C"; expect "major release: v2 started, v1 left on v1.7.0" '[ "$(commit_of v2)" = "$C" ] && [ "$(commit_of v1)" = "$B" ]'
rc=0; run v1.6.1 "$A" || rc=$?
expect "late older release (v1.6.1 on an older commit): tagged, v1 not moved back" '[ $rc -eq 0 ] && [ "$(commit_of v1.6.1)" = "$A" ] && [ "$(commit_of v1)" = "$B" ]'
printf 'commit:%s' "$A" > "$tmp/state/refs/v3"
rc=0; run v3.1.0 "$C" || rc=$?
expect "lightweight alias v3 on an older commit: moved forward to v3.1.0" '[ $rc -eq 0 ] && [ "$(commit_of v3)" = "$C" ]'
printf 'commit:%s' "$C" > "$tmp/state/refs/v4.0.0"
: > "$tmp/state/calls"; rc=0; run v4.0.0 "$C" || rc=$?
expect "lightweight version tag already on this commit: no write" '[ $rc -eq 0 ] && ! grep -qE "^(POST|PATCH) repos/o/r/git/refs/tags/v4.0.0" "$tmp/state/calls"'
D=$(printf 'd%.0s' {1..40})
printf 'commit:%s' "$D" > "$tmp/state/refs/v5"
rc=0; run v5.1.0 "$C" || rc=$?
expect "alias on a commit outside the history: stops, alias untouched" '[ $rc -ne 0 ] && [ "$(commit_of v5)" = "$D" ]'
touch "$tmp/state/fail-read"; : > "$tmp/state/calls"; rc=0; run v6.0.0 "$C" || rc=$?
expect "API error reading a tag (not 404): stops before writing" '[ $rc -ne 0 ] && ! grep -qE "^(POST|PATCH)" "$tmp/state/calls"'
rm -f "$tmp/state/fail-read"
exit $fail
