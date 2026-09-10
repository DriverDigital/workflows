# Handoff — 2026-09-10

State of play for the next session. Conventions, how-tos and release history live in
[`README.md`](../README.md); the agent-facing subset is [`CLAUDE.md`](../CLAUDE.md).

## Where things stand

`v1.15.0` (`15a34e9`) shipped and waved on 2026-09-10 — what it carries and the wave/audit numbers
live in README's [`v1.15.0`](../README.md#v1150-15a34e9-2026-09-10) section, its only home. The audit
read converged the same day (51 pins, 90 files, zero drift), the first time it counts the PR
template. The Dependabot proof from the 2026-08-22 handoff closed that morning: Dependabot opened
vite-plugin-shopify-clean #95 unaided, it was merged, and the repo was waved.

Nothing is in flight in this repo. The fleet's `claude.yml` now fails an issue run that leaves no PR
and keeps the full transcript in the job log — and **no real ticket has run on it yet**. That run is
the acceptance test (step 7 of the 2026-09-10 state-of-play), and reading its transcript is how the
Avara #195 diagnosis gets confirmed.

## Open decisions

- **Fable billing.** Unchanged since 2026-08-21: watch, don't gate; fallback `--model opus` (MODEL
  NOTE in `templates/github/claude.yml`). It needs an actual answer before the next `claude.yml`
  wave — [`claude-yml-wave-plan.md`](claude-yml-wave-plan.md).
- **Reusable conversion of `claude.yml`** — still **TABLED**, and the 2026-09-10 pin-model
  investigation strengthened the case: across the last eight releases, seven changed a whole-file
  kit file (`claude.yml` in six), so the per-repo commit per release is `claude.yml`'s churn, not the
  SHA pin. Mutable refs, an npm package, and ruleset-required workflows were assessed and declined
  — the dated note in [`reusable-conversion-scope.md`](reusable-conversion-scope.md).
- **Identity unification** — still **DEFERRED**;
  [`identity-unification-scope.md`](identity-unification-scope.md).

## Watch-items

- **The first real ticket through v1.15.0.** The guard step should stay quiet; if it fires, the
  failure note lands on the issue and the transcript is in the run log (`show_full_output`).
- **foundrae-blackridge@staging** will drift again: its Dependabot bumped `claude-code-action` to
  1.0.210 on 2026-09-02 (#174) and the wave brought it back to the kit's 1.0.201. The audit reports
  that as the kit being behind, which is the correct reading.
- **The cooldown exemption** is unverified live until a tag lands and a repo carrying the kit block
  bumps the same day; vite-plugin-shopify-clean is the one to watch at the next tag.
- **WebSearch/WebFetch** stay off: the caveat's condition (#690 fixed **and** the pin bumped) is half
  met by this release; #690 was still open at 2026-07-28. Re-check at the next pin bump.
- A human `@claude` (tag mode) still gets the action's own co-author text; the nine-item quality
  standard is global to `--append-system-prompt` — both unchanged.

## Recommended next steps

The 2026-09-10 state-of-play sets the order; the workflows-side pieces are:

1. **One real ticket end to end** on the v1.15.0 rail, transcript read. Pairs with the dispatcher
   heartbeat in driver-agents.
2. **The next `claude.yml` wave** — ride-alongs and gates in
   [`claude-yml-wave-plan.md`](claude-yml-wave-plan.md); the Figma REST wrapper (driver-agents) gates
   two of them, a Macroscope answer on headless CLI auth gates the third.
3. **Check Run agents pilot** (Avara first). When the prompts exist in driver-agents,
   `tools/fleet-wave.sh` gains `.macroscope/check-run-agents/` as a second file set — the `dest()`
   helper is where a second root goes.
4. **Fleet `dependabot.yml` audit** (to-do): the kit block, cooldown included, is the house-standard
   candidate; the five repos without a `github-actions` block are listed in
   [`fleet-operations.md`](fleet-operations.md#dependabot-and-the-wave).

## Pointers

- [`README.md`](../README.md) — release + repin order, what's in the kit, dated release history.
- [`fleet-operations.md`](fleet-operations.md) — wave mechanics, the fleet counts, what the pin audit
  cannot see, branch protection.
- [`claude-yml-wave-plan.md`](claude-yml-wave-plan.md) — the next implementer wave and its gates.
- [`macroscope-integration-scope.md`](macroscope-integration-scope.md) — the Macroscope → Bonsai
  build, and what replaced the retired bridge server. Observed 2026-09-10: it re-reviews every push,
  resolves its own threads once a push addresses them, and its verdict reads `Approved at <sha>`
  once nothing is left; a fleet-changing kit release gets "not approved" on risk with zero findings.
- `driver-agents` — the dispatcher (since 2026-09-10), the box-retirement spec, and
  `config/reviewers.json`, the live reviewer map.
