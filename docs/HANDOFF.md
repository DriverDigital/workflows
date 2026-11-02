# Handoff

State of play: what is in flight, blocked, open and next. Conventions and how-tos live in
[`README.md`](../README.md); the agent-facing subset is [`CLAUDE.md`](../CLAUDE.md). To-dos are the
open `todo` issues (`gh issue list --label todo`); this file points at them rather than copying them.

## In flight

- **v1.21.0 is released and waved; `fleet-pin-audit.sh --stale` reads converged.** Every site repo
  is on `main`, and the wave and the audit cover every `main-*` branch of a repo on `main`.
  - Pipeline repos (`agents-pipeline`): the ten Shopify repos, studio-sulzer, Driver-Digital-Website,
    Team-Laird and The-Gathery. Team-Laird and The-Gathery got `claude.yml` in this wave; their
    entries in driver-agents' repo map are separate work there.
  - A `shopify-theme.yml` stub copied from an older template fails at startup (the push job needs
    `pull-requests: write`).
- **Open PRs need a new event to pick up the wave.** A re-run of an old failed run reuses the old
  pin and stays red; a push, a merge of `main`, or a close and reopen runs the new stub. The PRs red
  on `theme / push` from the Shopify CLI 5 bug: foundrae-blackridge #249 and #252, Palmers #168–#174
  (drafts, one per country branch), Avara #258 and #262, LaPointe #170. Every repo on #99's list
  requires up-to-date, so its PRs read behind; Dependabot's need `@dependabot rebase`.
- **The next release:** #129, then #85 (make the Dependabot verdict a real check, then auto-merge on
  it), in their own session.
- **#99, the up-to-date org ruleset.** Not tied to a release. Its comments list the six repos whose
  required check to set first. First confirm every targeted branch reports the required check; a
  required context with no run blocks every merge.

## Blocked or gated

- **Real tickets through driver-engineering-app** wait on its security hardening pass.
- **WebSearch/WebFetch** stay off until anthropics/claude-code-action#690 is fixed. The action floats
  on `v1`, so the fix arrives on its own; then remove the caveat comment in `claude.yml`.

## Open decisions

- **npm or pnpm (#132).** Weighed on its own, not tied to the next wave.
- **#79 (ticket-assets screenshots) is tabled** until #95's Figma paragraph has run on real tickets
  (driver-agents #47 is the live test). `AGENTS_GH_PAT` can read `ticket-assets` if it is needed.

## Watch-items

- **Each repo's `todo` to drop its Volta pin, stray `.nvmrc` or Shopify `engines.node`** (from #86)
  can land now: CI builds on the kit's `.node-version`. A red implementer or validate build on a
  repo that still pins Volta is most likely the repo's own Node problem. driver-onboarding#41 adds
  mise to the setup docs.
- **First wave of `lint.yml`** on driver-onboarding, vite-plugin-shopify-clean, plugins and
  client-workspaces: a red `actionlint` there is a finding in the repo's own workflows.
- **After the v1.21.0 wave:** the first file Shopify rejects fails `theme / push` with a file annotation; the
  first `@claude` issue a person opens with no Bonsai task ends with a review request on its PR; the
  first implementer PR on an issue with acceptance criteria has a How to QA section after its
  Bonsai line, pointed at the right preview for the repo's platform.
- **The kit-tag cooldown exemption** is unverified live. Watch vite-plugin-shopify-clean's Dependabot
  PR for the v1.21.0 stub pins.
- **`claude-standards.md` on the comment path** is unverified (the issues path loads it). Have a
  collaborator's `@claude` ask the implementer to quote the attachment header; bot comments do not
  reach it.
- **The first implementer run after the wave** must show `--model opus --advisor fable` in its log.
- **The first implementer runs on Team-Laird and The-Gathery.** Team-Laird's build throws without
  `SANITY_API_READ_TOKEN`, which the implementer never gets; Team-Laird#86 names the no-secrets build
  in its `CLAUDE.md`. The-Gathery has no preview deploy, so its PRs carry QA steps with no preview link.
- **Palmers' `DRIVER/main-ma`** was created afresh at the cutover: the push found no unpublished theme
  of that name, though July's deploy had updated one (id 163173007417). It was deleted, renamed or
  published; check the Morocco store's admin.
- **The first real ticket through the implementer.** The guard steps should stay quiet; if one
  fires, the failure note lands on the issue and, on a private repo, the transcript is in the run log.
  On Avara the log must read `Provisioned store 'avara'` and the "Mint the store token as a log mask"
  step must pass. Never print the token cache to prove the mask.
- **Figma check-run agent spend.** It runs on PRs that touch theme or front-end paths in the pipeline
  Shopify repos, at most 4 runs a PR. A run with no design cost $0.27–$1.31 on Avara, more for bigger
  diffs; a run with a design is unmeasured (capped at $6 a run, $24 a PR).
- **A PR whose head is `main` or a `main-*` branch** would delete that branch's own `DRIVER/<branch>`
  theme when it closes: `shopify-theme.yml`'s cleanup deletes every non-live theme named after the
  head branch. None exists today (a foundrae `main-development` → `main` PR would be the first); the
  next push would recreate the theme under a new id.
- **A red validate on an old Dependabot PR** clears on `@dependabot rebase` or any push.

## Next steps

1. Give the open PRs above a new event: merge `main` in or push; close and reopen Palmers' drafts.
2. driver-agents#80 updates its README to match #120, and driver-agents#93 its `CLAUDE.md` kit row.
3. Add Team-Laird and The-Gathery to driver-agents' repo map, so tickets route to them.
4. #99: set the required checks its comments list, then the org ruleset.
5. Settle the open decisions above.

## Pointers

- [`README.md`](../README.md): the pipeline, the rails, the kit, release + repin order, and
  [Macroscope on a PR](../README.md#macroscope-on-a-pr).
- [`fleet-operations.md`](fleet-operations.md): wave mechanics, what the pin audit cannot see, branch
  protection.
- [`branch-model.md`](branch-model.md): the platform standards, the topics, and the cutover runbook.
- `driver-agents`: the dispatcher, the ticket map and the canonical Shopify instructions.
- The optional `repository_dispatch` trigger for the revise loop is #98.
