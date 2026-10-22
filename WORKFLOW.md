# Workflow

How work is planned and tracked in every repo of mine (apps, infra, this one): GitHub issues and
milestones, no plan files. The shared pieces live in this repo: the label set
([`labels.json`](labels.json)), the script that applies labels, merge and security settings
([`scripts/setup-github.sh`](scripts/setup-github.sh)), and the default issue and PR templates
([`.github/`](.github/)). For apps, the stack is in
[`app-template/STACK.md`](https://github.com/timblankers/app-template/blob/main/STACK.md).

## Files vs issues

- **Files describe how things are**: `CLAUDE.md`, `README.md`, `docs/decisions/`, architecture
  docs. Keep them accurate in the same PR that changes the code.
- **Issues track what still needs doing**: features, bugs, chores, ideas, open questions.
- No `PLAN.md`, `TODO.md`, `IDEAS.md` or `*-plan.md` files. An idea becomes an `idea` issue. A
  longer plan goes in the issue body (or a parent issue), not in the repo.

## Issues

- **One issue = one unit of work**: small enough for one session and one PR.
- Title says the outcome, in the imperative ("Add sourdough timer", not "Timer stuff").
- Body: one-line goal and a short "done when" checklist. The default templates (feature, bug,
  idea, decision) come from this repo; a repo only has its own when it really needs different ones.
- **Bigger things**: a parent issue with [sub-issues](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/adding-sub-issues).
  The parent holds the plan; each sub-issue is one PR.

## Labels

A fixed set, the same in every repo ([`labels.json`](labels.json)). Don't add others without
changing that file first, then run the setup script.

| Kind | Labels | Rule |
|---|---|---|
| Type | `feature`, `bug`, `chore`, `docs`, `decision` | Exactly one per issue |
| State | `idea`, `blocked` | `idea` = not committed to; drop it when it gets a milestone. `blocked` = say on what in a comment |
| Priority | `p1`, `p2` | Optional. No label = whenever |

An `idea` issue can stay type-less until it's picked up.

## Milestones

- **A milestone is a goal with an end**: "v0.2 Train redesign", "Phase 3 Keep things aligned".
  Not a category ("Backend", "Someday"): use labels for that, and no milestone for the backlog.
- Description: one line saying what's true when it's done. Due date optional.
- **Planned phases may all be open at once**, but they are ordered: start the title with
  "Phase N" or a version, or give them due dates. The **current** milestone is the first open one;
  the later ones hold work that is planned but not started.
- Only plan ahead what you're committed to. A milestone that has been untouched for months should
  be closed and its issues moved back to the backlog (or turned into `idea` issues).
- Close the milestone when its goal is met, even if some issues are moved to the next one.

## Flow

1. **Pick**: the open issues in the current milestone, `p1` first.
   `gh issue list --milestone "<name>"`
2. **Branch**: `<issue number>-<short-name>`, e.g. `42-train-timer` (`gh issue develop 42 -c`).
3. **PR**: title = what changed; body starts with `Closes #42`. CI must pass, where the repo has
   it (`check` in apps).
4. **Merge**: squash merge. The issue closes and counts toward the milestone; the branch is
   deleted.

Small doc fixes may be committed straight to `main` with `Closes #N` in the message.

Found something out of scope while working? Open an issue (usually `idea` or `bug`) instead of
widening the PR or leaving a TODO comment.

## For Claude

- Before starting work, find or create the issue it belongs to. Don't start a plan file.
- Use `gh` for everything: `gh issue list/view/create/edit`, `gh pr create`.
- New issues get exactly one type label, plus `idea` unless the user committed to doing it.
  Only assign a milestone when the user says so.
- When a session ends with work left over, write it down as issues (or a comment on the current
  issue), not in a file.

## New and existing repos

- **New repo**: add it to [`repos.txt`](repos.txt), run `scripts/setup-github.sh <owner/repo>
  --prune`, and create the first milestone. Don't copy the templates; the defaults apply.
  New apps start from `app-template`.
- **Existing repo**: map old labels first (`enhancement` → `feature`, `documentation` → `docs`),
  then run the script with `--prune`. Delete the repo's own issue/PR templates unless it needs
  different ones. Turn `PLAN.md` / `TODO.md` / `IDEAS.md` items into issues and delete those files.
