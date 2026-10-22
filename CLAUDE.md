# CLAUDE.md

## Purpose

Shared setup for all of Tim's repos under `github.com/timblankers` (apps and infra): default
community health files, the label set and repo-settings script, the reusable CI/deploy workflow and
the Renovate preset. See [`README.md`](README.md) for how other repos link to it.

## Layout

Grows phase by phase (see the milestones):

- `WORKFLOW.md`: how work is tracked (issues, milestones, labels, branch and PR flow).
- `labels.json`, `scripts/setup-github.sh`, `repos.txt`: labels and repo settings, pushed to repos.
- `.github/ISSUE_TEMPLATE/`, `.github/pull_request_template.md`: default templates for all repos.
- `.github/workflows/`: reusable workflows (`on: workflow_call`): `app.yml`, `secrets.yml`; `ci.yml` lints this repo.
- `gitleaks.toml`: default secret-scan rules and allowlist, used by `secrets.yml`.
- `scripts/check-conformance.sh`: STACK.md drift check, run by `app.yml`. Its check ids are an
  interface (a Claude skill matches on them): keep them stable.
- `default.json`: Renovate preset (`renovate.json` is this repo's own config, extending it).
- `claude/skills/`: source of Claude Code skills.

## Rules

- **Public repo.** No secrets, hostnames, tailnet names, IPs or other private details in files,
  commits or issues. Workflows read secrets from the calling repo (`secrets: inherit`).
- Work is tracked in GitHub issues and milestones, never in plan/TODO files.
- Verify GitHub behaviour against the current GitHub docs before relying on it.
- Use `gh` for all GitHub operations. Ask Tim before changing other repos (opening PRs there,
  running the setup script on them, setting secrets).
- Keep files small and commented. Prefer plain shell + `gh` + `jq` over extra tooling.
- Changes to shared files affect every repo at once: say so in the PR.

## Testing changes

- Shell scripts: `shellcheck scripts/*.sh`; run against a scratch or own repo first.
- Workflows: `actionlint`; then call the workflow from a branch of `app-template` with
  `uses: timblankers/.github/.github/workflows/app.yml@<branch>` before merging.
- Templates: check they show up when opening an issue/PR in a repo without its own copy.
