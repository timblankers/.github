# timblankers/.github

The one place for everything that is the same across all my repos: how work is tracked, and
shared automation. It is public; it holds no secrets or private details.

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

## Not here

The app stack and app skeleton are not here; they live in
[`app-template`](https://github.com/timblankers/app-template), because they're about apps only.

Work on this repo is tracked in [issues and milestones](https://github.com/timblankers/.github/milestones).
