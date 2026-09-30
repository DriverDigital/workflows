# The next `claude.yml` wave — plan

What the next fleet wave of the implementer carries, what gates each item, and how a `claude.yml`
wave is run. Release mechanics live in [`README.md`](../README.md) ("Release + repin order") and
[`fleet-operations.md`](fleet-operations.md); this doc is only the *what* and the *when*. Revised
2026-09-30 against driver-agents main @ `21a357c`.

## Shape: the wave is the reusable conversion

Maria, 2026-09-30: go on converting `claude.yml` to a reusable + thin stub, spike first. **The spike
passed the same day**, so the next wave ships the stub, and every ride-along below lands once in the
reusable instead of in 18 copies. Design,
risks and the corrected silent-skip guard: [`reusable-conversion-scope.md`](reusable-conversion-scope.md)
(2026-09-30 update at the top).

**Built on branch `claude-yml-reusable`:** the conversion and every ride-along below except the two
gated ones (WebSearch / WebFetch, and the optional `repository_dispatch`).

The model does not change: `--model fable --effort xhigh` stays (Maria, 2026-09-30 — quality is good,
don't disturb it). Fable billing is no longer tracked; the MODEL NOTE in the header goes.

## Ride-alongs

None is gated except where stated.

| Item | What changes | Source |
|---|---|---|
| **Macroscope loop cleanup** | Delete the `ticketed-review-round` prompt arm and the "Re-request ticketed review" step (and its comment block). Drop the `Reviewer:` handling from issue-prompt steps (1) and (7) — no more `gh pr edit --add-reviewer`; the Bonsai assignment is the review request. Keep the actor carve-out. `CLAUDE.md`'s "three arms" invariant becomes two in the same PR. | driver-agents spec 2026-09-18 §3, §9 |
| **Bonsai task URL** | Step (7) writes `Bonsai task: <url>` from the issue's `**Bonsai task:**` line, replacing "do NOT copy any task URL" (header lines 19-20 too). `pull_request_template.md`'s Bonsai section becomes `Bonsai task: <url> \| none`. A new whole-file kit workflow on `pull_request` opened/edited fails unless the body carries an `app.hellobonsai.com/tasks/<uuid>` URL or `Bonsai task: none`, exempting `dependabot[bot]`; added to `FULL_FILES`, made a required check per repo only after the wave. The `gh pr create` hook is out: the wave only writes under `.github/`. | driver-agents spec 2026-09-15 §11 |
| **Store changes in the PR body** | Step (7) asks the implementer to list store changes it made (metaobjects, metafields, definitions) in plain words among the what-changed bullets — the dispatcher's Bonsai hand-off summary reads the PR body only. | driver-agents #40 |
| **Comments and commits** | `--append-system-prompt` item (7): replace "Detail belongs in commit messages and code comments." with the Code comments standard from `claude-standards.md`, reworded to carry **no apostrophe** ("where it's used" would truncate the prompt). Item (4): "implement what is warranted, and record what you dismissed and why" → "fix the warranted ones in code". Item (6): commit messages are succinct — what changed, plus any rationale a later developer needs. | foundrae-blackridge #194 |
| **Figma MCP** | `claude_args` gains the inline `--mcp-config` exactly as driver-agents `.github/workflows/figma-mcp-smoke.yml` (never a file path — dropped in tag mode), `--allowedTools` gains `mcp__figma`, job env `MAX_MCP_OUTPUT_TOKENS: "200000"`, and `.github/workflows/lint.yml`'s quote gate (`:97-99`) goes 4 → 6. Rewrite CAVEAT 2 and [`figma-mcp-in-ci.md`](figma-mcp-in-ci.md)'s verdict: node JSON is readable, Driver-plan files only (client-owned files 403), writes never offered, and **no rendered image reaches the model** until a canary proves `figma_get_image` does. Reusable: declare `FIGMA_MCP_SECRET` `required: false`. | Gate cleared: smoke green, run 34982197161 |
| **Canonical Shopify blockquote** | Re-copy the whole blockquote from driver-agents `docs/agent-instructions-shopify.md` at the new ref (14a0162 added a field-description sentence; f13b7a8 dropped the box credential path from the tripwire), parity-check, and move `DRIVER_AGENTS_REF` in `claude.yml` **and** `shopify-tool-smoke.yml` to a main at or after `21a357c`. | CLAUDE.md invariants |
| **Header comment** | Line 18: `driver-bonsai-mcp` → driver-agents `pipeline-dispatch.yml`. Delete the Fable MODEL NOTE (38-40). | — |
| **Prompt check follows the prompt** | Conversion only: repoint `.github/workflows/lint.yml`'s tokenization and quote-count step (and `CLAUDE.md`'s Commands and first invariant) at the reusable's `claude_args` and `prompt:`, and make it fail loudly when it finds no `claude_args` — a stub has no `steps`. | reusable-conversion-scope Phase 4 |
| **WebSearch / WebFetch** | Re-add to `--allowedTools`. | **Gated:** anthropics/claude-code-action#690 fix. The kit floats on `v1`; the caveat comment is what gets removed. |
| **repository_dispatch on a Macroscope review** (optional) | On `pull_request_review` submitted by `macroscopeapp` on a `claude[bot]` PR, fire driver-agents `pipeline-dispatch.yml` for latency. | **Gated:** `AGENTS_GH_PAT` needs Contents: write on driver-agents — check first. |

## Running it

1. ~~Spike~~ — passed 2026-09-30, green and red (reusable-conversion-scope, Phase 0 result).
2. ~~Write the reusable and the stub, then edit the kit; run the local CI checks~~ — done on
   `claude-yml-reusable`.
3. Merge and tag. At step 2 of the release order, replace `templates/github/claude.yml` with the stub
   below, pinned to the tag (it cannot land earlier: the pin does not exist, and `lint.yml` refuses
   the placeholder), then delete the stub from this doc.
4. Set the repository variable `SHOPIFY_STORE_NAME=avara` on Avara — the wave refuses Avara until it
   is set.
5. `tools/fleet-wave.sh --dry-run`, then canary with `--only vite-plugin-shopify-clean`: one
   `@claude` issue must open a `claude[bot]` PR carrying a `Bonsai task:` line, with no
   `Skipping action due to workflow validation` in the log; a plain comment must skip the job with no
   runner, and the "Trusted authors" step must list collaborators with the default token (if it
   cannot, switch that step to `AGENTS_GH_PAT`).
6. Wave, then `tools/fleet-pin-audit.sh --stale` must read converged. On Avara, the first store run's
   log must read `Provisioned store 'avara'` — the proof that `vars` resolves against the caller.
7. Run one real ticket through with the transcript on (`show_full_output`) and read it before calling
   the wave done. Then make `bonsai-link` a required check per repo.

The stub (`templates/github/claude.yml` from the release):

```yaml
name: Claude Code

# CALLER STUB — the implementer. Everything but the triggers, the concurrency group and the
# permissions lives in the reusable this pins (DriverDigital/workflows .github/workflows/claude.yml),
# including the actor gate that decides whether a trigger runs.
#
# Silent failures if edited:
#   • Each of the five permissions is required. The reusable can only narrow them, and without
#     `id-token: write` the Claude App token cannot mint.
#   • `secrets: inherit` carries the org-level SHOPIFY_ALERT_WEBHOOK; an explicit map that forgot it
#     would switch destructive-call alerts off on a green run.
#   • The token exchange requires this file to match its copy on the default branch, so it only
#     works once merged there. A mismatch is a green run that did nothing, which the reusable fails.
# The store handle is the SHOPIFY_STORE_NAME repository variable; leave it unset without a store.

# issue_comment and pull_request_review_comment stay [created]: the implementer edits its own
# comment, and subscribing to `edited` would re-run it on itself.
on:
  issue_comment:
    types: [created]
  issues:
    # 'opened' only — 'assigned' would re-launch the implementer when an @claude'd issue is assigned.
    types: [opened]
  pull_request_review:
    types: [submitted]
  pull_request_review_comment:
    types: [created]

jobs:
  claude:
    # Coarse: load the reusable only when @claude is present. It holds the real actor gate, but a
    # call is validated before that gate runs, so without this every comment or review on a fork
    # PR (no secrets, read-only token) would fail red. Skipped runs also stay out of the
    # concurrency group below, so a later comment without @claude cannot cancel a queued run.
    if: >-
      (github.event_name == 'issues' && contains(github.event.issue.body, '@claude')) ||
      (github.event_name != 'issues' && contains(github.event.comment.body || github.event.review.body, '@claude'))
    # Review events carry pull_request.number, not issue.number.
    concurrency:
      group: claude-${{ github.event.pull_request.number || github.event.issue.number }}
      cancel-in-progress: false
    permissions:
      contents: write
      pull-requests: write
      issues: write
      id-token: write
      actions: read
    uses: DriverDigital/workflows/.github/workflows/claude.yml@0000000000000000000000000000000000000000 # vX.Y.Z
    secrets: inherit
```
