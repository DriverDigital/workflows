# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@templates/github/claude-standards.md

## Read first

- `docs/HANDOFF.md` — state of play, open decisions, what the next session should do.
- The open `todo` issues on this repo (`gh issue list --label todo`; the driver-skills hook lists
  them at session start). Re-list before a wave; another session may have filed since.
- `README.md` — what this repo is, where it sits in the pipeline, how the kit and releases work.
  This file is the subset an agent breaks by accident; README is the authority where they overlap.
  The kit's install steps: `templates/github/README.md`.

## What this is

The GitHub side of Driver's agentic pipeline: the reusable workflows in `.github/workflows/` (the
implementer `claude.yml`, three Dependabot rails, one rail per hosting platform) and the onboarding
kit in `templates/github/` that fleet repos install. `driver-agents` (private) holds the dispatcher
that feeds the implementer and the canonical Shopify instructions it runs with. README,
*Where it sits in the pipeline*, has the whole picture.

Two files in `.github/workflows/` are this repo's own CI, not products: `lint.yml` and
`dependabot-auto-merge.yml`. **`.github/workflows/lint.yml` and `templates/github/lint.yml` are
different files** with the same name and the same job id `actionlint` (the required-check context).

PR review is Macroscope's, org-wide. Claude reviews a PR only when a person `@claude`s it. The
implementer's own `/code-review` pass before it opens a PR is implementing — keep it. Never add an
automatic Claude review of an opened PR.

## Commands

No build, no test suite. CI is `lint.yml`; reproduce it locally before pushing:

```sh
brew install actionlint shellcheck jq         # CI pins actionlint 1.7.12 (VERSION + SHA256 in lint.yml — bump together)
SHELLCHECK_OPTS='--exclude=SC2015' actionlint -color                         # globs .github/workflows/
SHELLCHECK_OPTS='--exclude=SC2015' actionlint -color templates/github/*.yml  # kit; the dependabot/ variants are not workflows
grep -rn 'DriverDigital/workflows/.*@0\{40\}' templates/github/              # must print nothing (placeholder-pin guard)
pipx run check-jsonschema==0.38.2 --builtin-schema vendor.dependabot templates/github/dependabot/*.yml
```

`lint.yml` also checks that the prompt survives tokenization (the python step at
the `lint.yml` step "claude.yml system prompt survives tokenization"; run it verbatim, needs PyYAML, after any edit to the reusable
`claude.yml`'s `claude_args` or `prompt:`) and that the Shopify blockquote matches driver-agents
`main` (it reads driver-agents with `AGENTS_GH_PAT`, and also runs daily).

Fleet tools (both work through `gh api`, no clones; both need authenticated `gh` and `jq`, the wave
also `actionlint`):

```sh
tools/fleet-pin-audit.sh            # full drift report; --stale for drifted rows only; non-zero on any drift
tools/fleet-wave.sh --dry-run       # plan the wave, touches nothing; allowed from any branch
tools/fleet-wave.sh --only <repo>   # canary one repo (all its kit branches)
tools/fleet-wave.sh                 # every driver-kit repo — only from a clean main that contains the tag
tools/fleet-wave.sh --message "chore(kit): … [skip ci]"   # override the commit message
```

## Releasing

Follow README *Release + repin order*; the order is load-bearing. The trap: **push the tag.** The
wave reads it locally (`git describe`) and the audit reads it from GitHub, so an unpushed tag waves
clean and then audits as stale everywhere.

A new reusable's stub lands in step 2 of the release that tags it, never in the PR that adds the
reusable. A kit-only change needs no tag and no wave. A driver-agents change to a check-run agent
reads as audit drift until a wave from `main` with `--message` carries it. Wave mechanics:
`docs/fleet-operations.md`.

## Invariants that fail silently

- `.github/workflows/claude.yml` `--append-system-prompt`: **no apostrophe, no `$`, no newline** —
  shell-quote truncates rather than errors, every flag still parses, a repin ships the truncated prompt
  fleet-wide green. `claude_args` holds exactly six single quotes (`--allowedTools`, `--mcp-config`,
  `--append-system-prompt`). The `prompt:` scalar is a `format()` literal: the only permitted brace
  is `{0}`.
- The Shopify blockquote inside `--append-system-prompt` is a verbatim copy of driver-agents
  `docs/agent-instructions-shopify.md` — edit there first, then re-copy. Canonical begins at
  `All Shopify Admin API calls go through`; everything before it (conduct block, quality standard, and
  the lead-in that un-scopes the tripwire from them) is ours and must survive the re-copy.
  `lint.yml` compares it with driver-agents `main`, whitespace collapsed (the copy flattens one
  paragraph break); a red check there means re-copy, then release.
- The implementer and the kit's `shopify-tool-smoke.yml` clone driver-agents `main` for the Shopify
  admin tool, and the wave and the audit read the check-run agents (`AGENT_FILES` in
  `tools/kit-platforms.sh`) from it too: driver-agents' PR review is the only gate on that code. The
  store handle is the `SHOPIFY_STORE_NAME` repository variable, read by both; unset = no store
  tooling.
- Third-party actions float on their major tag in the reusables and the kit (README, *Action refs*).
  A SHA in `templates/` is a pin nothing bumps.
- Stubs pin this repo's reusables by immutable SHA, never a moving `@v1`: a moved tag would reach every
  store-secret repo with no canary, and the audit's convergence check and `--only` canaries depend on
  the pin.
- `dependabot-validate` stub `name:` stays byte-identical (`Dependabot validate`) — `-report`'s
  `workflow_run` name-matches it. The job always runs and branches internally; never `if:`-skip it.
- `templates/github/claude-standards.md` is style only — never permissions, tool rules or hooks. On a PR
  run claude-code-action restores `CLAUDE.md` and `.claude/` from the base branch but not `.github/`, so
  the `@` import resolves to the PR head's copy and a collaborator's branch can change what it loads.
  Load-bearing rules go in `CLAUDE.md` or `.claude/`.
- Never `pull_request_target`. Never set `anthropic_api_key` (overrides OAuth, bills at API rates).
- Never pass the action a `github_token` as a fallback for a failed App token exchange: the PR author
  becomes `driver-digital-agents` instead of `claude[bot]`, and the identity split below breaks.
- The `claude.yml` reusable's `actions/checkout` keeps `persist-credentials` at default —
  claude-code-action's early fetch 403s on a private repo without it. The Dependabot reusables' checkouts
  set it `false` on purpose.
- The `claude.yml` reusable's `prompt:` has two arms: the branch-and-PR prompt on issue events, and
  **empty** (tag mode) for every comment, the dispatcher's revise-loop `@claude` included.
- The `claude.yml` stub grants all five permissions and passes `secrets: inherit`. The reusable can
  only narrow permissions (without `id-token: write` no App token mints), and an explicit secrets map that forgot
  the org-level `SHOPIFY_ALERT_WEBHOOK` switches destructive-call alerts off on a green run. The
  reusable's job-level `if:` is the actor gate, with its logins and ids literal in the reusable, never
  `workflow_call` inputs a caller could widen; the stub's is a coarse `@claude` filter that keeps
  a fork PR's comments from loading the reusable (a call is validated before its gate runs) and
  keeps skipped runs out of the job-level concurrency group.
- The reusable's "Trusted authors" step is the prompt-injection defense: only collaborators,
  `driver-digital-agents` and four named bots reach Claude through `include_comments_by_actor`, and a run on
  an issue or PR written by anyone else is refused, since the action cannot filter a body, as is a
  fork PR. It runs first, before checkout and provisioning, and fails
  the run when the collaborator list cannot be read — never fall back to an empty filter, which
  includes everyone.
- `GH_TOKEN` on `gh` steps is `AGENTS_GH_PAT` (`driver-digital-agents`). Deliberate exceptions use the
  default token: `claude.yml`'s trusted-authors check, its no-PR check and its failed-run notice (posts
  as github-actions[bot] so it cannot re-trigger the workflow), and this repo's
  `dependabot-auto-merge.yml`.
- The `claude.yml` stub's `issue_comment` and `pull_request_review_comment` triggers stay
  `types: [created]`. The implementer's final answer edits its own comment; subscribing to `edited`
  re-runs it on itself.
- Two identities, and the split is load-bearing: `claude[bot]` implements and authors PRs,
  `driver-digital-agents` dispatches, summons and authors issues. The actor gate and driver-agents'
  `dispatch.sh` guards both key on it, and the dispatcher's revise loop runs through the gate's
  `driver-digital-agents` carve-out — keep it.
- Never write the skip-ci token in a commit message that isn't meant to skip CI — GitHub scans the
  whole message, and a PR with *no* check runs looks healthy.
- Branch protection: `PATCH` the subresource; a `PUT` replaces the whole object and drops the
  approval rule (creating a missing status-check rule needs one: carry every field over and diff). This repo keeps `enforce_admins: false` and is pushed to directly on purpose.
- A platform file (`tools/kit-platforms.sh`) never goes to a repo whose topic names another platform
  or none, nothing goes to a repo without `driver-kit`, and a repo with more than one platform topic
  blocks the wave. A new platform file must be added to the list there, or neither the wave nor the
  audit sees it.
- No wave runs while a repo is mid-cutover: the wave reads `default_branch` live.
- A new fleet rail that shares `claude.yml`'s trigger wakes a real implementer run on a client repo;
  pilot on the PR leg (`docs/fleet-operations.md` → "Piloting a cross-repo reusable").
