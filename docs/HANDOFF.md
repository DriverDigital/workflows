# Handoff — 2026-08-22

State of play for the next session. Conventions, how-tos and release history live in
[`README.md`](../README.md); the agent-facing subset is [`CLAUDE.md`](../CLAUDE.md).

## Where things stand

`v1.13.0` (`f6d25d3`) shipped and waved on 2026-08-22 — the release that sets the rail up to run
without the box. The fleet is converged and the pipeline is proven end to end by the canary. What
shipped, the canary run and the wave/audit numbers live in README's
[`v1.13.0`](../README.md#v1130-f6d25d3-2026-08-22) section, which is their only home.

Nothing is in flight: no open branch, no half-finished wave, no pending secret deletion.

## Open decisions

- **Fable billing.** The canary ran clean on `claude-fable-5`; whether it draws usage credits was
  never checked. The decision (2026-08-21) is to watch it as pipeline traffic grows rather than gate
  on it. Fallback is `--model opus` — see the MODEL NOTE comment in `templates/github/claude.yml`.
- **`DRIVER_AGENTS_REF` bump + tripwire re-copy.** Held at `4d63371`; driver-agents `main` is 8
  commits ahead with a longer canonical blockquote and small tool fixes. Do it in the next release
  that wants those, following release-order step 1 — not as a release of its own.
- **Reusable conversion of `claude.yml`** — still **TABLED**. The 2026-08-22 research weakens the
  OIDC blocker — the Phase 0 spike is now a confirmation, not a go/no-go — and its own lazy read
  is *not yet*: `fleet-wave.sh` took most of the win at zero build cost. The assessment that went
  to Maria leans the other way (it is still the file that changed in 6 of the last 8 releases) —
  her call. It also found the risk that has to be designed around — since claude-code-action PR
  #1417 a workflow-validation failure is a **silent green skip**, so a canary must assert
  `::warning::Skipping action due to workflow validation` is absent. 20–27h;
  [`reusable-conversion-scope.md`](reusable-conversion-scope.md).
- **Identity unification** — still **DEFERRED**, but cheaper than its doc said: retiring the review
  rails deleted its Phase 3 and its worst silent-failure risk, re-costing it at 21–24h. The 58–61%
  API-ceiling drop stands and is still the argument against;
  [`identity-unification-scope.md`](identity-unification-scope.md).

## The Dependabot finding

"Dependabot never bumps our reusable pins" is false. It does — when a repo has a `github-actions`
block and a tag lands before the wave (Palmers #93 and vite-plugin-shopify-clean #72, 2026-07-02).
In practice the wave repins within minutes of every tag so Dependabot never gets a turn, and 5 of
the 13 distinct repos behind the 20 pairs have no `github-actions` block at all, because the kit
ships the stubs but has never shipped a `dependabot.yml`. The fix is to ship one in the kit and
sequence the wave after it instead of racing it; the free test is to not wave
vite-plugin-shopify-clean after the next tag and watch for a PR. Detail and recommendation:
[`fleet-operations.md`](fleet-operations.md#dependabot-and-the-wave), the single home for this.

## Ride along with the next `claude.yml` release

None of these earns a wave on its own.

- `templates/github/claude.yml:21` points at `docs/phase2-github-setup.md`, which exists in no repo.
- The fleet's `pull_request_template.md` copies still credit the retired **status sync** with
  resolving the linked issue. The kit copy is corrected, but `tools/fleet-wave.sh`'s file set does
  not include that file — either add it or re-onboard the repos.
- The Figma MCP caveat line, per [`figma-mcp-in-ci.md`](figma-mcp-in-ci.md) (v1.13.0 passed without
  it).

## Watch-items

- The nine-item quality standard is **global** to `--append-system-prompt`, so it reaches the
  ticketed revision rail too — watch the first revision round against the 90-minute cap.
- A human `@claude` (tag mode) still gets the action's own co-author text; the attribution setting
  covers the agent rails only.
- `/code-review`'s 50-file cap means a large migration gets a partial pre-review. The prompt requires
  the run to say so — check that it does.
- The first real ticket through the rail. The canary was torn down, so nothing has run since.

## Recommended next steps

From the 2026-08-22 assessment — recommendations, not decisions.

1. **Kit `dependabot.yml` + sequencing** (above). Smallest change on the list, it removes the
   stub-pin half of the wave (the whole-file copies — `claude.yml`, `shopify-tool-smoke.yml`,
   `lint.yml` — still need `fleet-wave.sh`), and the proving test costs nothing.
2. **Reusable conversion of `claude.yml`.** Weaker than it was — `tools/fleet-wave.sh` took most of
   the win at zero build cost — but still real: `claude.yml` changed in 6 of the last 8 releases.
3. **Re-cost identity unification before starting 2.** It deletes the conversion's Phase 0 outright,
   so identity-first may simply be the cheaper order.
4. Cheap and unscoped: the kit's `lint.yml` is fleet-uniform, touches no OIDC path, and is the one
   file that could become a reusable without any of the above blocking it.

## Pointers

- [`README.md`](../README.md) — release + repin order, what's in the kit, dated release history.
- [`fleet-operations.md`](fleet-operations.md) — wave mechanics, the fleet counts, what the pin audit
  cannot see, branch protection.
- [`macroscope-integration-scope.md`](macroscope-integration-scope.md) — the Macroscope → Bonsai
  build, and what replaced the retired bridge server.
- `driver-bonsai-mcp` — the pipeline dispatcher, its box-retirement spec
  (`docs/superpowers/specs/2026-08-21-box-retirement-dispatcher-design.md` §5a), and
  `config/reviewers.json`, the live reviewer map.
