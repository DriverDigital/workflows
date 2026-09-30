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
2. Write the reusable and the stub, then edit the kit; run the four local CI checks (`CLAUDE.md` → Commands), including the tokenization
   step, which is the only automated check on the prompt.
3. Merge, tag, repin, then `tools/fleet-wave.sh --dry-run` and canary with
   `--only vite-plugin-shopify-clean`. On the canary, assert the log does not contain
   `::warning::Skipping action due to workflow validation` — a validation failure is a silent green skip.
4. Wave, then `tools/fleet-pin-audit.sh --stale` must read converged.
5. Run one real ticket through with the transcript on (`show_full_output`) and read it before calling
   the wave done.
