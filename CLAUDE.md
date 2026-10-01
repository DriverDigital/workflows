# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@templates/github/claude-standards.md

## Read first

- `docs/HANDOFF.md` — state of play, open decisions, what the next session should do.
- The open `todo` issues on this repo — the to-dos (the driver-skills hook lists them at session
  start; `gh issue list --label todo`). Re-list before a wave; another session may have filed since.
- `README.md` — the full conventions and the dated release history. This file is the subset an
  agent breaks by accident; README is the authority where they overlap.

## What this is

The public home of Driver's Bonsai→GitHub pipeline workflows. Two products live here:

- **Reusables** in `.github/workflows/` — `workflow_call`-only: `claude.yml` (the implementer) and the
  three Dependabot rails (`dependabot-validate` / `-report` / `-keep-current`). The two review rails
  retired at v1.12.0 were deleted 2026-09-30; any tag through `v1.16.0` still holds them.
- **The onboarding kit** in `templates/github/` — what fleet repos copy into `.github/workflows/`:
  four caller stubs pinning a reusable by immutable SHA (`claude.yml` and the Dependabot three), plus
  three whole-file workflows (`shopify-tool-smoke.yml` store repos only, `lint.yml`,
  `pr-bonsai-link.yml` beside `claude.yml`) and `pull_request_template.md` and `claude-standards.md`
  (both live at `.github/`; the wave carries them) and `dependabot.yml` (hand-installed — merged into a repo's existing file, never copied over it).
  Kit install conventions: `templates/github/README.md`.

PR review is Macroscope's, org-wide (Maria, 2026-09-12): Claude reviews a PR only when a person `@claude`s it
(optionally naming `/code-review`). The implementer's own `/code-review` pass before it opens a PR is
implementing, not PR review — keep it. Never add an automatic Claude review of an opened PR —
`docs/macroscope-integration-scope.md`.

Two more files in `.github/workflows/` are this repo's own CI, not products: `lint.yml` and
`dependabot-auto-merge.yml`. **`.github/workflows/lint.yml` and `templates/github/lint.yml` are
different files** with the same name and the same job id `actionlint` (the required-check context).

The Macroscope revise loop lives in the driver-agents dispatcher, which summons the implementer with a
plain tag-mode `@claude` (driver-agents spec 2026-09-18 §3, §9). The actor carve-out that admits
`driver-digital-agents` is what the loop runs through — keep it.

Sibling repo: `driver-agents` (private; the dispatcher, plus the canonical Shopify instructions
pinned by `DRIVER_AGENTS_REF`) — README, *How the repos fit together*. `driver-bonsai-mcp`, the
dispatcher until 2026-09-10, was archived 2026-09-11 — every mention of it is history.

## Commands

No build, no test suite. CI is `lint.yml`; reproduce it locally before pushing:

```sh
brew install actionlint shellcheck jq         # CI pins actionlint 1.7.12 (VERSION + SHA256 in lint.yml — bump together)
SHELLCHECK_OPTS='--exclude=SC2015' actionlint -color                         # globs .github/workflows/
SHELLCHECK_OPTS='--exclude=SC2015' actionlint -color $(ls templates/github/*.yml | grep -v dependabot.yml)  # kit; dependabot.yml is not a workflow
grep -rn 'DriverDigital/workflows/.*@0\{40\}' templates/github/              # must print nothing (placeholder-pin guard)
```

Two more CI checks: the prompt survives tokenization (the python step at
`.github/workflows/lint.yml:82`; run it verbatim, needs PyYAML, after any edit to the reusable
`claude.yml`'s `claude_args` or `prompt:`), and `DRIVER_AGENTS_REF` matches in the reusable and
`shopify-tool-smoke.yml` (the step after it). Those check the first and third invariants below; the rest
are unenforced, and the blockquote parity check in particular is by hand at release time.

Fleet tools (both work through `gh api`, no clones; the audit needs only authenticated `gh`, the wave
also `jq` + `actionlint`):

```sh
tools/fleet-pin-audit.sh            # full drift report; --stale for drifted rows only; non-zero on any drift
tools/fleet-wave.sh --dry-run       # plan the wave, touches nothing; allowed from any branch
tools/fleet-wave.sh --only <repo>   # canary one repo (all its kit branches)
tools/fleet-wave.sh                 # the whole fleet — only from a clean main that contains the tag
tools/fleet-wave.sh --message "chore(kit): … [skip ci]"   # override the commit message
```

## Releasing — the order is load-bearing

1. Merge to `main`, cut the tag **and push it** — the wave reads the tag locally (`git describe`),
   the audit reads it from GitHub, so an unpushed tag waves clean and then reports everything stale.
   If `DRIVER_AGENTS_REF` moved, run the blockquote parity check first (README, release-order
   step 1) — nothing else re-checks it.
2. Repin every stub in `templates/github/` to the tag's SHA **and** its `# vX.Y.Z` trailer (one sed;
   they are one pin). `lint.yml` fails on a placeholder pin; `fleet-wave.sh` refuses an unrepinned kit.
3. `fleet-wave.sh --dry-run`, then for real — one direct `[skip ci]` commit per branch, not PRs —
   then `fleet-pin-audit.sh --stale` must report converged.

A kit-only change (no reusable touched, no pin moved) needs no tag and no wave; it rides with the next
release. Cutting a tag is what creates the obligation to wave. A new reusable's stub lands in step 2 of
the *next* release, not in the PR that adds the reusable. Full detail and the v1.11.0 stub-conversion
caveats: README "Release + repin order"; wave mechanics and fleet counts: `docs/fleet-operations.md`.

## Invariants that fail silently

- `.github/workflows/claude.yml` `--append-system-prompt`: **no apostrophe, no `$`, no newline** —
  shell-quote truncates rather than errors, every flag still parses, a repin ships the truncated prompt
  fleet-wide green. `claude_args` holds exactly six single quotes (`--allowedTools`, `--mcp-config`,
  `--append-system-prompt`). The `prompt:` scalar is a `format()` literal: the only permitted brace
  is `{0}`.
- The Shopify blockquote inside `--append-system-prompt` is a verbatim copy of driver-agents
  `docs/agent-instructions-shopify.md` — edit there first, then re-copy. Canonical begins at
  `All Shopify Admin API calls go through`; everything before it (conduct block, quality standard, and
  the lead-in that un-scopes the tripwire from them) is ours and must survive the re-copy. Parity
  is checked with whitespace collapsed (the copy flattens one paragraph break).
- `DRIVER_AGENTS_REF` lives in the reusable `claude.yml` **and** the kit's `shopify-tool-smoke.yml`; same
  SHA in both (lint-checked), or the smoke test verifies a revision the implementer never runs. The
  store handle is the `SHOPIFY_STORE_NAME` repository variable, read by both; unset = no store tooling.
  Dependabot cannot bump the ref: a raw SHA in `env:`, and it scans only `.github/workflows/`, never `templates/`. That is also why the kit's
  whole-file workflows reference third-party actions by major tag (`@v1`, `@v7`) — a SHA there is a
  pin nothing bumps while a fleet repo's Dependabot bumps its copy when the action releases. The
  reusables float the same way; majors are the only action bumps that get a PR anywhere.
- `dependabot-validate` stub `name:` stays byte-identical (`Dependabot validate`) — `-report`'s
  `workflow_run` name-matches it. The job always runs and branches internally; never `if:`-skip it.
- Never `pull_request_target`. Never set `anthropic_api_key` (overrides OAuth, bills at API rates).
- The `claude.yml` reusable's `actions/checkout` keeps `persist-credentials` at default —
  claude-code-action's early fetch 403s on a private repo without it. The Dependabot reusables' checkouts
  set it `false` on purpose.
- The `claude.yml` reusable's `prompt:` has two arms: the branch-and-PR prompt on issue events, and
  **empty** (tag mode) for every comment, the dispatcher's revise-loop `@claude` included.
- The `claude.yml` stub grants all five permissions and passes `secrets: inherit`. The reusable can
  only narrow permissions (without `id-token: write` no App token mints), and an explicit secrets map that forgot
  the org-level `SHOPIFY_ALERT_WEBHOOK` switches destructive-call alerts off on a green run. The
  reusable's job-level `if:` is the actor gate; the stub's is a coarse `@claude` filter that keeps
  a fork PR's comments from loading the reusable (a call is validated before its gate runs) and
  keeps skipped runs out of the job-level concurrency group.
- The reusable's "Trusted authors" step is the prompt-injection defense: only collaborators,
  `driver-digital-agents` and four named bots reach Claude through `include_comments_by_actor`, and a run on
  an issue or PR written by anyone else is refused, since the action cannot filter a body, as is a
  fork PR. It runs first, before checkout and provisioning, and fails
  the run when the collaborator list cannot be read — never fall back to an empty filter, which
  includes everyone.
- `GH_TOKEN` on `gh` steps is `AGENTS_GH_PAT` (`driver-digital-agents`). Deliberate exceptions use the
  default token: `claude.yml`'s failed-run notice (posts as github-actions[bot] so it cannot re-trigger
  the workflow) and its no-PR check, and this repo's `dependabot-auto-merge.yml`.
- The `claude.yml` stub's `issue_comment` and `pull_request_review_comment` triggers stay
  `types: [created]`. The implementer's final answer edits its own comment; subscribing to `edited`
  re-runs it on itself.
- Two identities, and the split is load-bearing: `claude[bot]` implements and authors PRs,
  `driver-digital-agents` dispatches, summons and authors issues. The actor gate and driver-agents'
  `dispatch.sh` guards both key on it.
- Never write the skip-ci token in a commit message that isn't meant to skip CI — GitHub scans the
  whole message, and a PR with *no* check runs looks healthy.
- Branch protection: `PATCH` the subresource; a `PUT` replaces the whole object and drops the
  approval rule. This repo keeps `enforce_admins: false` and is pushed to directly on purpose.
- A new fleet rail that shares `claude.yml`'s trigger wakes a real implementer run on a client repo;
  pilot on the PR leg (`docs/fleet-operations.md` → "Piloting a cross-repo reusable").
