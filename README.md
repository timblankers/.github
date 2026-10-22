# timblankers/.github

The one place for everything that is the same across all my repos: how work is tracked, and
shared automation. How work is tracked is in [`WORKFLOW.md`](WORKFLOW.md). It is public; it holds no secrets or private details.

It links to the other repos in three ways:

1. **Automatic defaults.** GitHub uses the community health files here (issue templates, PR
   template, CONTRIBUTING, SECURITY, …) for any of my repos that has no copy of its own. Nothing
   in the other repos points here; it works by this repo's name. A repo's own copy always wins.
2. **Explicit references.** Apps call the reusable CI/deploy workflow
   (`uses: timblankers/.github/.github/workflows/<file>.yml@<ref>`) and extend the Renovate preset
   (`"extends": ["github>timblankers/.github"]`).
3. **Pushed out from here.** GitHub has no shared default for labels and repo settings, so this
   repo holds the label set and a script that applies labels and settings to a repo.

## Labels and repo settings

[`labels.json`](labels.json) is the fixed label set from [`WORKFLOW.md`](WORKFLOW.md).
[`scripts/setup-github.sh`](scripts/setup-github.sh) applies it to a repo, together with the merge
settings (squash only, PR title + body as the commit, delete branch on merge) and the security
settings (Dependabot alerts on, actions must be pinned to a full commit SHA):

```bash
scripts/setup-github.sh timblankers/<repo>          # one repo
scripts/setup-github.sh --all --prune               # every repo in repos.txt, drop other labels
```

New repo: add it to [`repos.txt`](repos.txt) and run the script. Needs `gh` (logged in) and `jq`.

Not in the script: this repo's "Protect main" ruleset (PRs only, squash, CI must pass), set by hand
because private repos on the free plan can't have rulesets.

## Default templates

[`.github/ISSUE_TEMPLATE/`](.github/ISSUE_TEMPLATE/) (feature, bug, idea, decision) and
[`.github/pull_request_template.md`](.github/pull_request_template.md) are used by every repo of
mine, private ones included, that has no templates of its own. A repo with any valid template or
`config.yml` in its own `.github/ISSUE_TEMPLATE/` uses none of these, so delete repo copies rather
than editing them. They stay Markdown: issue forms are still in public preview.

## Shared CI and deploy for apps

[`.github/workflows/app.yml`](.github/workflows/app.yml) implements app-template's decision 008.
All jobs run on `ubuntu-24.04-arm`; runner minutes are billed to the calling repo.

| Job | Runs on | Does |
|---|---|---|
| `conformance` | PRs, default branch | `scripts/check-conformance.sh` against the app (see [Conformance check](#conformance-check)) |
| `check` | PRs, default branch | Postgres service → `npm ci` (Node from `.nvmrc`) → `npm run check` |
| `image` | PRs, default branch | Build the arm64 image (GHA cache) → run it next to Postgres → seed → Playwright WebKit E2E against it → on the default branch, push that image as `ghcr.io/timblankers/<app>:<sha>` |
| `deploy` | default branch, if `deploy: true` (after the other three pass) | Join the tailnet as ephemeral `tag:ci` → `ssh deploy@<pi> <app> <sha>` |

What the workflow expects from an app (besides decision 008's image contract):

- `.nvmrc`, `package-lock.json`, a `Dockerfile` at the root taking the `APP_VERSION` build arg.
- `npm run check` uses `DATABASE_URL` (an empty `app_test` database) for tests that need Postgres.
- `npm run db:seed` (optional) seeds `DATABASE_URL`; it runs after the app has migrated.
- `npm run test:e2e` targets `BASE_URL` when set and then skips Playwright's `webServer`.

Inputs: `app-name` (default: repo name), `postgres-version` (`18`), `seed-command`,
`e2e-command`, `deploy` (`true`).

### The whole `ci.yml` an app needs

```yaml
# .github/workflows/ci.yml — CI and deploy via timblankers/.github (see its README)
name: ci

on:
  pull_request:
  push:
    branches: [main]

# The shared workflow can only lower these, so grant what it needs here.
permissions:
  contents: read
  packages: write # push the image to GHCR

# New pushes to a PR cancel its running CI; runs on main always finish.
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  app:
    uses: timblankers/.github/.github/workflows/app.yml@main
    secrets: inherit # deploy secrets, see below
    with:
      deploy: false # until the app is set up on the Pi
```

Apps pin `@main`: a change here reaches every app on its next run, so test workflow changes by
pointing one app's `ci.yml` at the branch (`app.yml@<branch>`) before merging.

## Conformance check

[`scripts/check-conformance.sh`](scripts/check-conformance.sh) checks an app against
app-template's [`STACK.md`](https://github.com/timblankers/app-template/blob/main/STACK.md). It
prints `PASS <id> <message>` or `FAIL <id> <message>` per check (a FAIL message says what to
change), then `<n> failed`, and exits 1 if any check failed. `app.yml` runs it as the
`conformance` job, so CI fails on drift and `deploy` waits for it.

Run it locally from an app's root (needs `bash`, `jq`, `gh` for the download):

```bash
gh api repos/timblankers/.github/contents/scripts/check-conformance.sh -H 'Accept: application/vnd.github.raw' | bash -s -- .
```

or from a checkout of this repo: `scripts/check-conformance.sh ../<app>`.

| Id | Passes when | Source |
|---|---|---|
| `nvmrc-exact` | `.nvmrc` holds one exact Node version (`x.y.z`) | 002 |
| `devengines-node` | `package.json` `devEngines.runtime` is `node` at the `.nvmrc` version, `onFail: "error"` | 002 |
| `devengines-npm` | `devEngines.packageManager` is `npm` at an exact version, `onFail: "error"` | 002 |
| `npmrc` | `.npmrc` has `min-release-age=1` and `engine-strict=true` | 002 |
| `lockfile` | `package-lock.json` exists; no `bun.lock(b)`, `yarn.lock` or `pnpm-lock.yaml` | 002 |
| `scripts` | `dev`, `build`, `start`, `typecheck`, `lint`, `format`, `format:check`, `knip`, `test`, `test:e2e`, `check` exist | 004 |
| `no-plan-files` | no `PLAN.md`, `TODO.md`, `IDEAS.md` or `*-plan.md` (any case) outside `node_modules`, `.git`, `.claude` | [WORKFLOW.md](WORKFLOW.md) |
| `claude-md` | `CLAUDE.md` exists | 007 |
| `dockerfile` | `Dockerfile` has `ARG NODE_IMAGE=node:<.nvmrc version>-trixie-slim` (a `@sha256:` digest may follow) | 008 |
| `healthz` | `app/routes/healthz.ts` exists | 008 |
| `ci-shared` | a workflow in `.github/workflows/` calls `timblankers/.github/.github/workflows/app.yml` | this README |

The ids are stable: tools (and a Claude skill) match on them. Change a check's id only together
with its users. Numbers are app-template's
[decision records](https://github.com/timblankers/app-template/tree/main/docs/decisions).

## Renovate preset

[`default.json`](default.json) is the one Renovate config for all repos. A repo uses it with a
`renovate.json` at its root:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>timblankers/.github"]
}
```

What it does:

- `config:recommended`, plus a **weekly** schedule (early Monday, UTC) and a dependency dashboard
  issue.
- **Minor and patch updates in one PR**; majors get their own.
- **`minimumReleaseAge: "1 day"`**, matching `.npmrc`'s `min-release-age=1` (decision 002), so
  update PRs don't fail `npm ci`.
- **GitHub Actions pinned by SHA** (with the version as a comment), except this repo's own
  `app.yml@main`, which apps follow on purpose.
- **The Dockerfile base image pinned by digest** (`ARG NODE_IMAGE=node:<x.y.z>-trixie-slim@sha256:…`,
  decision 008).
- **One Node.js PR** updates `.nvmrc`, the Dockerfile `NODE_IMAGE` and `devEngines.runtime`
  together, and only to **LTS** releases (decision 002: no odd/Current majors). The Node release
  waits 3 days so its Docker image exists by then; if the PR still misses the Dockerfile, the
  `dockerfile` conformance check fails until Renovate adds it.
  - **By hand in that PR**: set `devEngines.packageManager.version` to the npm bundled with the new
    Node (the `npm` field in <https://nodejs.org/dist/index.json>; the PR body says so). Renovate
    never bumps npm on its own: it would pick the latest standalone npm instead.
  - With a Node **major**, also bump `@types/node`'s major (Renovate skips those).
- **TypeScript stays on 6.0.x** until typescript-eslint supports 7 (decision 004). Remove that rule
  when it does.

CI here runs `renovate-config-validator` on the preset. Changing `default.json` changes every
repo's next Renovate run.

### Which repos use it

Renovate runs (Mend Renovate GitHub App, "Only select repositories") on every repo in
[`repos.txt`](repos.txt): **app-template, .github, rpi-infra, tailnet, sourdough, daily-leaf and
pixel-perfect**. To add a repo: add `renovate.json` as above, then add the repo to the app's repository selection
(github.com/settings/installations → Renovate → Configure).

## Not here

The app stack and app skeleton are not here; they live in
[`app-template`](https://github.com/timblankers/app-template), because they're about apps only.

Work on this repo is tracked in [issues and milestones](https://github.com/timblankers/.github/milestones).
