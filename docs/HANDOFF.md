# Handoff — 2026-09-30

State of play for the next session. Conventions, how-tos and release history live in
[`README.md`](../README.md); the agent-facing subset is [`CLAUDE.md`](../CLAUDE.md).

## Where things stand

2026-09-30: **the Phase 0 spike passed**, green and red: the Claude App token mints inside a
SHA-pinned cross-repo reusable, and the corrected silent-skip guard turns a validation skip red. Runs
and detail: [`reusable-conversion-scope.md`](reusable-conversion-scope.md), "Phase 0 result".

**The conversion is built** on branch `claude-yml-reusable` (PR open, awaiting Macroscope): the
`claude.yml` reusable with every ungated ride-along, `pr-bonsai-link.yml`, the store handle as a
repository variable, and the tools and lint that follow. The kit stub is parked in
[`claude-yml-wave-plan.md`](claude-yml-wave-plan.md) until release step 2; that doc's "Running it"
is the release checklist from merge to the real ticket.

Earlier the same day (#59) the to-do list was re-validated and Maria settled the open decisions:

- **The two retired review rails are deleted** from `.github/workflows/` — this repo was their last
  home (fleet callers went at v1.12.0); any tag through `v1.16.0` still holds them.
- **Identity unification is dropped**, its scope doc deleted: the `claude[bot]` /
  `driver-digital-agents` split is load-bearing for the driver-agents review loop. The two invariants
  worth keeping moved into `CLAUDE.md`.
- **`claude.yml` becomes a reusable + stub**, and the next `claude.yml` wave is that
  conversion carrying every ride-along: [`claude-yml-wave-plan.md`](claude-yml-wave-plan.md),
  [`reusable-conversion-scope.md`](reusable-conversion-scope.md).
- **The model stays `fable`**; Fable billing is no longer tracked. **Marcella-NYC-Main review
  coverage: not doing it.**
- **The round-marker arm is dead, not a re-entry point.** The Macroscope revise loop shipped in the
  driver-agents dispatcher (2026-09-18) using a plain tag-mode `@claude`, and the Macroscope → Bonsai
  receiver was retired unbuilt (2026-09-29). [`macroscope-integration-scope.md`](macroscope-integration-scope.md)
  now describes the loop.
- **House standards ship as a kit file**, `templates/github/claude-standards.md`, imported by
  `CLAUDE.md` here; fleet repos copy it once and the wave keeps it current (added to `FULL_FILES` and
  the audit).

The last release is still [`v1.16.0`](../README.md#v1160-ff3ff34-2026-09-10) (2026-09-10). The audit
reads one drifted row, driver-engineering-app's hand-installed `lint.yml` (a to-do is filed there).

## Open decisions

- **`dependabot-report`'s future.** It runs Claude automatically on every Dependabot PR (verdict over
  the inert artifact, never the diff). Macroscope reviews Dependabot PRs too since 2026-09-10, so it is
  the one place two bots still review automatically. Keep, or retire like the review rails.

## Watch-items

- **The first real ticket through v1.15.0.** The guard step should stay quiet; if it fires, the
  failure note lands on the issue and the transcript is in the run log (`show_full_output`).
- **Major bumps of the kit's floated actions.** `actions/checkout@v7`, `actions/upload-artifact@v7`
  and `anthropics/claude-code-action@v1` float in the kit; when a new major ships, a fleet repo's
  Dependabot moves ahead and the audit reads the kit as behind until the kit's major is bumped.
  Below a major boundary the foundrae-blackridge #174 drift-and-rollback cannot recur.
- **The cooldown exemption** is unverified live until a tag lands and a repo carrying the kit block
  bumps the same day; vite-plugin-shopify-clean is the one to watch at the next tag.
- **WebSearch/WebFetch** stay off until #690 ships a fix (still open at 2026-07-28); the action
  floats on `v1`, so the fix arrives on its own and the caveat comment in `claude.yml` is what gets
  removed.
- **`claude-standards.md` loading in CI.** claude-code-action loads project settings by default, so
  the `@` import should reach the implementer; confirm on the first fleet repo that adopts it.
- A human `@claude` (tag mode) still gets the action's own co-author text; the nine-item quality
  standard is global to `--append-system-prompt` — both unchanged.

## Recommended next steps

1. **Release the conversion** once driver-engineering-app is ready (Maria, 2026-09-30): its
   hand-installed `lint.yml` is the audit's one drifted row, and any hardening that touches the
   app's secret names or driver-agents `tools/shopify` must land before the tag (a `tools/shopify`
   change moves `DRIVER_AGENTS_REF` again). driver-agents #43 (token mask, `pr-view` Bonsai filter,
   no `Reviewer:` line) is merged and pinned at `0397630`; Avara's `SHOPIFY_STORE_NAME` variable is
   set. Then Macroscope, merge, tag `v1.17.0`, land the stub, canary, wave, real ticket —
   [`claude-yml-wave-plan.md`](claude-yml-wave-plan.md), "Running it".
2. **One real ticket end to end** on the new rail, transcript read.
3. **`fleet-wave.sh` gains `.macroscope/check-run-agents/`** — after the first real Avara design
   ticket tunes the rubric (driver-agents #32 holds the prompt; Avara's copy merged 2026-09-29). The
   `dest()` helper is where a second root goes.
4. **Fleet `dependabot.yml` standard** (to-do): the kit block, cooldown included, is the candidate;
   the gaps are in [`fleet-operations.md`](fleet-operations.md#dependabot-and-the-wave).

## Pointers

- [`README.md`](../README.md) — release + repin order, what's in the kit, dated release history.
- [`fleet-operations.md`](fleet-operations.md) — wave mechanics, the fleet counts, what the pin audit
  cannot see, branch protection.
- [`claude-yml-wave-plan.md`](claude-yml-wave-plan.md) — the next implementer wave and its gates.
- [`macroscope-integration-scope.md`](macroscope-integration-scope.md) — the 2026-09-12 decision that
  Macroscope owns automatic review, and the driver-agents loop that replaced the review rails. Observed 2026-09-10: it re-reviews every push,
  resolves its own threads once a push addresses them, and its verdict reads `Approved at <sha>`
  once nothing is left; a fleet-changing kit release gets "not approved" on risk with zero findings.
- `driver-agents` — the dispatcher (since 2026-09-10) and the box-retirement spec.
