# Handoff — 2026-10-01

State of play for the next session. Conventions, how-tos and release history live in
[`README.md`](../README.md); the agent-facing subset is [`CLAUDE.md`](../CLAUDE.md).

## Where things stand

2026-10-01: **v1.17.0 is released and waved.** `claude.yml` is a reusable + thin stub (#60), the canary
on vite-plugin-shopify-clean passed every assertion in [`claude-yml-wave-plan.md`](claude-yml-wave-plan.md)
"Running it", all 21 targets are on the tag, and the audit reads converged (driver-agents' hand-installed `lint.yml`,
outside the wave, was re-copied by hand the same night, `ed2ad6a`). Release record and what is not yet
proven: [`README.md`](../README.md#v1170-359505a-2026-10-01).

To-dos are the open `todo` issues on this repo since 2026-10-01 (#61–#64 carry the former
`CLAUDE.local.md` items); that file is retired across Driver repos.

2026-09-30 (#59) settled the decisions the release was built on:

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

## Open decisions

- **`dependabot-report`'s future.** It runs Claude automatically on every Dependabot PR (verdict over
  the inert artifact, never the diff). Macroscope reviews Dependabot PRs too since 2026-09-10, so it is
  the one place two bots still review automatically. Keep, or retire like the review rails.

## Watch-items

- **The first real ticket through v1.17.0.** The guard steps should stay quiet; if one fires, the
  failure note lands on the issue and, on a private repo, the transcript is in the run log.
- **Major bumps of the kit's floated actions.** `actions/checkout@v7`, `actions/upload-artifact@v7`
  and `anthropics/claude-code-action@v1` float in the kit; when a new major ships, a fleet repo's
  Dependabot moves ahead and the audit reads the kit as behind until the kit's major is bumped.
  Below a major boundary the foundrae-blackridge #174 drift-and-rollback cannot recur.
- **The cooldown exemption** is still unverified live: at v1.17.0 the wave repinned within minutes of
  the tag, so Dependabot had nothing to bump. vite-plugin-shopify-clean remains the one to watch.
- **WebSearch/WebFetch** stay off until #690 ships a fix (still open at 2026-07-28); the action
  floats on `v1`, so the fix arrives on its own and the caveat comment in `claude.yml` is what gets
  removed.
- **`claude-standards.md` loading in CI** — confirmed on the issues path (Avara run 36789868486 carried
  both `CLAUDE.md` and `.github/claude-standards.md` as attachments; Avara #226, 2026-10-01). The
  comment path is still unverified: the `@claude` must come from a collaborator or the dispatcher (bot
  comments are `author_association` NONE), and the transcript never prints loaded instructions, so
  have the implementer quote the attachment header. The PR-run gap (the import resolves to the PR
  head's copy) is accepted: the file is style-only, now a `CLAUDE.md` invariant (Maria, 2026-10-01).
- A human `@claude` (tag mode) still gets the action's own co-author text; the nine-item quality
  standard is global to `--append-system-prompt` — both unchanged.

## Recommended next steps

1. ~~Make `bonsai-link` a required check per repo~~ — dropped (Maria, 2026-10-01): the check skips
   PRs with no Bonsai mention, since most human PRs have no ticket and a red X read as a failing
   build; a required check that passes when skipped would enforce nothing.
   The wave also installs `claude-standards.md` beside `claude.yml` since 2026-10-01; the
   `@.github/claude-standards.md` import is a `todo` issue in each repo that lacks it.
   driver-agents joins the fleet as an implementer target (driver-agents #50, Maria 2026-10-01); the
   next wave after its kit install reaches 22 targets.
2. **One real ticket end to end** on the new rail, transcript read (private repos log it) — after
   driver-engineering-app's security hardening pass (Maria, 2026-10-01: a couple of weeks; she will
   not run tickets through the app before it). On Avara, the first store run's log must read
   `Provisioned store 'avara'` and the "Mint the store token as a log mask" step must pass — never
   print the token cache to prove the mask.
3. **Ride-along for the next reusable change** (#70, part 2): reword `claude.yml`'s
   `--append-system-prompt` item (7) to the revised comments standard — a tight summary, no apostrophes,
   no newline — then release, repin and wave as usual. Not urgent (Maria, 2026-10-01).
4. **`fleet-wave.sh` gains `.macroscope/check-run-agents/`** (#61) — after the first real Avara design
   ticket tunes the rubric (driver-agents #32 holds the prompt; Avara's copy merged 2026-09-29). The
   `dest()` helper is where a second root goes.
5. **Fleet `dependabot.yml` standard** (#62): the kit block, cooldown included, is the candidate;
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
