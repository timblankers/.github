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
settings (squash only, PR title + body as the commit, delete branch on merge):

```bash
scripts/setup-github.sh timblankers/<repo>          # one repo
scripts/setup-github.sh --all --prune               # every repo in repos.txt, drop other labels
```

New repo: add it to [`repos.txt`](repos.txt) and run the script. Needs `gh` (logged in) and `jq`.

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
| `check` | PRs, default branch | Postgres service → `npm ci` (Node from `.nvmrc`) → `npm run check` |
| `image` | PRs, default branch | Build the arm64 image (GHA cache) → run it next to Postgres → seed → Playwright WebKit E2E against it → on the default branch, push that image as `ghcr.io/timblankers/<app>:<sha>` |
| `deploy` | default branch, if `deploy: true` | Join the tailnet as ephemeral `tag:ci` → `ssh deploy@<pi> <app> <sha>` |

What the workflow expects from an app (besides decision 008's image contract):

- `.nvmrc`, `package-lock.json`, a `Dockerfile` at the root taking the `APP_VERSION` build arg.
- `npm run check` uses `DATABASE_URL` (an empty `app_test` database) for tests that need Postgres.
- `npm run db:seed` (optional) seeds `DATABASE_URL`; it runs after the app has migrated.
- `npm run test:e2e` targets `BASE_URL` when set and then skips Playwright's `webServer`.

Inputs: `app-name` (default: repo name), `postgres-version` (`18`), `seed-command`,
`e2e-command`, `deploy` (`true`).

## Not here

The app stack and app skeleton are not here; they live in
[`app-template`](https://github.com/timblankers/app-template), because they're about apps only.

Work on this repo is tracked in [issues and milestones](https://github.com/timblankers/.github/milestones).
