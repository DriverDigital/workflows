# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Read first

- `docs/HANDOFF.md` — state of play, open decisions, what the next session should do.
- `CLAUDE.local.md` — to-dos (gitignored). Re-read before a wave; another repo's session may have
  appended since.
- `README.md` — the full conventions and the dated release history. This file is the subset an
  agent breaks by accident; README is the authority where they overlap.

## What this is

The public home of Driver's Bonsai→GitHub pipeline workflows. Two products live here:

- **Reusables** in `.github/workflows/` — `workflow_call`-only. Three live Dependabot rails
  (`dependabot-validate` / `-report` / `-keep-current`); two review rails (`pr-first-review`,
  `ticketed-review`) are retired-inert with banners, callers deleted fleet-wide at v1.12.0.
- **The onboarding kit** in `templates/github/` — what fleet repos copy into `.github/workflows/`:
  three caller stubs pinning a reusable by immutable SHA, plus three whole-file workflows
  (`claude.yml` the implementer, `shopify-tool-smoke.yml` store repos only, `lint.yml`) and
  `pull_request_template.md` (lives at `.github/`; the wave carries it since v1.15.0) and
  `dependabot.yml` (hand-installed — merged into a repo's existing file, never copied over it).
  Kit install conventions: `templates/github/README.md`.

Two more files in `.github/workflows/` are this repo's own CI, not products: `lint.yml` and
`dependabot-auto-merge.yml`. **`.github/workflows/lint.yml` and `templates/github/lint.yml` are
different files** with the same name and the same job id `actionlint` (the required-check context).

`claude.yml` is a full per-repo copy, not a reusable — the kit's main drift surface. Its ticketed-loop
machinery (round-marker prompt arm, actor carve-out, re-request step) looks dead with the review rails
gone; it is the designed re-entry point for the Macroscope revise loop
(`docs/macroscope-integration-scope.md` — live, not research). Do not strip it.

Sibling repos: `driver-bonsai-mcp` (the dispatcher) and `driver-agents` (private; canonical Shopify
instructions, pinned by `DRIVER_AGENTS_REF`) — README, *How the three repos fit together*.

## Commands

No build, no test suite. CI is `lint.yml`; reproduce it locally before pushing:

```sh
brew install actionlint shellcheck jq         # CI pins actionlint 1.7.12 (VERSION + SHA256 in lint.yml — bump together)
SHELLCHECK_OPTS='--exclude=SC2015' actionlint -color                         # globs .github/workflows/
SHELLCHECK_OPTS='--exclude=SC2015' actionlint -color $(ls templates/github/*.yml | grep -v dependabot.yml)  # kit; dependabot.yml is not a workflow
grep -rn 'DriverDigital/workflows/.*@0\{40\}' templates/github/              # must print nothing (placeholder-pin guard)
```

The fourth CI check — `claude.yml`'s prompt survives tokenization — is the python step at
`.github/workflows/lint.yml:81`; run it verbatim (needs PyYAML) after any edit to `claude.yml`'s
`claude_args` or `prompt:`. It is the only automated check for the first invariant below; the rest are
unenforced, and the blockquote parity check in particular is by hand at release time.

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

- `templates/github/claude.yml` `--append-system-prompt`: **no apostrophe, no `$`, no newline** —
  shell-quote truncates rather than errors, every flag still parses, a wave copies the truncated prompt
  fleet-wide green. `claude_args` holds exactly four single quotes. The `prompt:` scalar is a
  `format()` literal: the only permitted brace is `{0}`.
- The Shopify blockquote inside `--append-system-prompt` is a verbatim copy of driver-agents
  `docs/agent-instructions-shopify.md` — edit there first, then re-copy. Canonical begins at
  `All Shopify Admin API calls go through`; everything before it (conduct block, quality standard, and
  the lead-in that un-scopes the tripwire from them) is kit-side and must survive the re-copy. Parity
  is checked with whitespace collapsed (the kit flattens one paragraph break).
- `DRIVER_AGENTS_REF` lives in `claude.yml` **and** `shopify-tool-smoke.yml`; same SHA in both, or the
  smoke test verifies a revision the implementer never runs. Dependabot cannot bump it: a raw SHA in
  `env:`, and it scans only `.github/workflows/`, never `templates/`. That is also why the kit's
  whole-file workflows reference third-party actions by major tag (`@v1`, `@v7`) — a SHA there is a
  pin nothing bumps while a fleet repo's Dependabot bumps its copy when the action releases. The
  reusables float the same way; majors are the only action bumps that get a PR anywhere.
- `dependabot-validate` stub `name:` stays byte-identical (`Dependabot validate`) — `-report`'s
  `workflow_run` name-matches it. The job always runs and branches internally; never `if:`-skip it.
- Never `pull_request_target`. Never set `anthropic_api_key` (overrides OAuth, bills at API rates).
- `claude.yml`'s `actions/checkout` keeps `persist-credentials` at default — claude-code-action's
  early fetch 403s on a private repo without it. The reusables' checkouts set it `false` on purpose.
- `claude.yml`'s `prompt:` has three arms: the branch-and-PR prompt on issue events, the round-marker
  prompt on a `driver-digital-agents` comment carrying the ticketed-review marker, and **empty** (tag
  mode) for every human `@claude`.
- `GH_TOKEN` on `gh` steps is `AGENTS_GH_PAT` (`driver-digital-agents`). Two deliberate exceptions use
  the default token: `claude.yml`'s failed-run notice (posts as github-actions[bot] so it cannot
  re-trigger the workflow) and this repo's `dependabot-auto-merge.yml`.
- Never write the skip-ci token in a commit message that isn't meant to skip CI — GitHub scans the
  whole message, and a PR with *no* check runs looks healthy.
- Branch protection: `PATCH` the subresource; a `PUT` replaces the whole object and drops the
  approval rule. This repo keeps `enforce_admins: false` and is pushed to directly on purpose.
- A new fleet rail that shares `claude.yml`'s trigger wakes a real implementer run on a client repo;
  pilot on the PR leg (`docs/fleet-operations.md` → "Piloting a cross-repo reusable").
