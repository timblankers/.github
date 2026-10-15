#!/usr/bin/env bash
# Checks an app against app-template's STACK.md (decisions 002, 004, 007, 008) and the
# workflow in WORKFLOW.md. Prints one line per check, then "<n> failed"; exits 1 on any failure.
#
#   scripts/check-conformance.sh [app-dir]     # default: .
#
# Output lines are "PASS <id> <message>" or "FAIL <id> <message>". The ids are stable (tools
# and the README depend on them); a FAIL message says what to change. Needs bash, find, grep, jq.
set -uo pipefail

dir=${1:-.}
if [ ! -d "$dir" ]; then
  echo "usage: $0 [app-dir]" >&2
  exit 2
fi
cd "$dir" || exit 2

failed=0
pass() { echo "PASS $1 $2"; }
fail() { echo "FAIL $1 $2"; failed=$((failed + 1)); }

# package.json field as text ("" when the file or field is missing).
pkg() { jq -r "$1 // empty" package.json 2>/dev/null; }

semver='^[0-9]+\.[0-9]+\.[0-9]+$'

# nvmrc-exact: .nvmrc holds one exact Node version (002).
# node_version stays "" unless .nvmrc is exact; later checks compare against it.
node_version=""
nvmrc=""
[ -f .nvmrc ] && nvmrc=$(tr -d '[:space:]' < .nvmrc)
if [[ $nvmrc =~ $semver ]]; then
  node_version=$nvmrc
  pass nvmrc-exact ".nvmrc pins Node $node_version"
elif [ -f .nvmrc ]; then
  fail nvmrc-exact ".nvmrc holds '$nvmrc': write the exact Active LTS version, e.g. 24.21.0"
else
  fail nvmrc-exact "no .nvmrc: add one with the exact Active LTS version, e.g. 24.21.0"
fi

# devengines-node: package.json devEngines.runtime is node at the .nvmrc version (002).
rt_name=$(pkg .devEngines.runtime.name)
rt_version=$(pkg .devEngines.runtime.version)
rt_fail=$(pkg .devEngines.runtime.onFail)
if [ "$rt_name" = node ] && [ -n "$node_version" ] && [ "$rt_version" = "$node_version" ] &&
  [ "$rt_fail" = error ]; then
  pass devengines-node "devEngines.runtime is node $rt_version (onFail: error)"
else
  fail devengines-node "set package.json devEngines.runtime to {\"name\": \"node\", \"version\": \"${node_version:-<.nvmrc version>}\", \"onFail\": \"error\"} (now: ${rt_name:-none} ${rt_version:-none}, onFail ${rt_fail:-none})"
fi

# devengines-npm: devEngines.packageManager is npm at an exact version (002).
pm_name=$(pkg .devEngines.packageManager.name)
pm_version=$(pkg .devEngines.packageManager.version)
pm_fail=$(pkg .devEngines.packageManager.onFail)
if [ "$pm_name" = npm ] && [[ $pm_version =~ $semver ]] && [ "$pm_fail" = error ]; then
  pass devengines-npm "devEngines.packageManager is npm $pm_version (onFail: error)"
else
  fail devengines-npm "set package.json devEngines.packageManager to {\"name\": \"npm\", \"version\": \"<npm bundled with the .nvmrc Node>\", \"onFail\": \"error\"} (now: ${pm_name:-none} ${pm_version:-none}, onFail ${pm_fail:-none})"
fi

# npmrc: release-age gate and engine-strict (002).
npmrc_has() { [ -f .npmrc ] && grep -Eq "^[[:space:]]*$1[[:space:]]*=[[:space:]]*$2[[:space:]]*$" .npmrc; }
missing=""
npmrc_has min-release-age 1 || missing+=" min-release-age=1"
npmrc_has engine-strict true || missing+=" engine-strict=true"
if [ -z "$missing" ]; then
  pass npmrc ".npmrc has min-release-age=1 and engine-strict=true"
else
  fail npmrc "add to .npmrc:$missing"
fi

# lockfile: package-lock.json only (002).
others=""
for f in bun.lock bun.lockb yarn.lock pnpm-lock.yaml; do
  [ -e "$f" ] && others+=" $f"
done
if [ -f package-lock.json ] && [ -z "$others" ]; then
  pass lockfile "package-lock.json is the only lockfile"
elif [ -n "$others" ]; then
  [ -e bunfig.toml ] && others+=" bunfig.toml"
  fail lockfile "delete$others and use npm (package-lock.json)"
else
  fail lockfile "no package-lock.json: run npm install and commit it"
fi

# scripts: decision 004's standard script names.
missing=""
for s in dev build start typecheck lint format format:check knip test test:e2e check; do
  [ -n "$(pkg ".scripts[\"$s\"]")" ] || missing+=" $s"
done
if [ -z "$missing" ]; then
  pass scripts "package.json has all standard scripts (004)"
else
  fail scripts "add these package.json scripts (decision 004):$missing"
fi

# no-plan-files: plans, ideas and TODOs live in GitHub issues (WORKFLOW.md).
plans=$(find . \( -name node_modules -o -name .git -o -name .claude \) -prune -o -type f \
  \( -iname PLAN.md -o -iname TODO.md -o -iname IDEAS.md -o -iname '*-plan.md' \) -print |
  sed 's|^\./||' | sort | tr '\n' ' ')
if [ -z "$plans" ]; then
  pass no-plan-files "no PLAN.md, TODO.md, IDEAS.md or *-plan.md"
else
  fail no-plan-files "move these to GitHub issues and delete them: ${plans% }"
fi

# claude-md: Claude's context for the app (007).
if [ -f CLAUDE.md ]; then
  pass claude-md "CLAUDE.md exists"
else
  fail claude-md "add CLAUDE.md (start from app-template's)"
fi

# dockerfile: the image (008), its Node version in sync with .nvmrc.
if [ ! -f Dockerfile ]; then
  fail dockerfile "add a Dockerfile (start from app-template's, decision 008)"
elif [ -n "$node_version" ] &&
  grep -Eq "^ARG NODE_IMAGE=node:${node_version//./\\.}-trixie-slim(@sha256:[0-9a-f]{64})?$" Dockerfile; then
  pass dockerfile "Dockerfile uses node:$node_version-trixie-slim"
else
  fail dockerfile "Dockerfile needs 'ARG NODE_IMAGE=node:${node_version:-<.nvmrc version>}-trixie-slim' (same Node as .nvmrc, decision 008)"
fi

# healthz: the health endpoint (008).
if [ -f app/routes/healthz.ts ]; then
  pass healthz "app/routes/healthz.ts exists"
else
  fail healthz "add app/routes/healthz.ts (GET /healthz with a DB check, decision 008)"
fi

# ci-shared: CI calls the shared workflow.
if grep -Eqs '^[[:space:]]*uses:[[:space:]]*timblankers/\.github/\.github/workflows/app\.yml@' \
  .github/workflows/*.yml .github/workflows/*.yaml; then
  pass ci-shared "CI calls timblankers/.github/.github/workflows/app.yml"
else
  fail ci-shared "make .github/workflows/ci.yml call timblankers/.github/.github/workflows/app.yml@main (see the timblankers/.github README)"
fi

echo "$failed failed"
[ "$failed" -eq 0 ]
