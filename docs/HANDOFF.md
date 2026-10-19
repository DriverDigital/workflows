# Handoff

State of play: what is in flight, blocked, open and next. Conventions and how-tos live in
[`README.md`](../README.md); the agent-facing subset is [`CLAUDE.md`](../CLAUDE.md). To-dos are the
open `todo` issues (`gh issue list --label todo`); this file points at them rather than copying them.

## In flight

- **v1.20.0 is released and waved; `fleet-pin-audit.sh --stale` reads converged.** The cutovers
  (#91) are under way: savannahfriedkin, LittleMe, Kissy-Kissy and R-Finds are done.
  - LittleMe's, Kissy-Kissy's and R-Finds' pushes created a new `DRIVER/main`; the old
    `DRIVER/develop` (LittleMe, R-Finds) and `Kissy-2.0/develop` themes are still in their admins, to
    delete.
  - R-Finds #46 (draft) adds the `.shopifyignore` lines that stop `assets/.vite/manifest.json` being
    rejected on every push; its preview push was clean.
  - Every other Shopify default branch still lacks the `shopify-theme.yml` stub until its cutover,
    so draft-PR previews and the description link start per repo then. A stub copied from an
    older template fails at startup (the push job needs `pull-requests: write`).
- **#113, #115 and #118 are on a draft PR here** and reach the fleet with the next release and
  wave. The push job reads both Shopify CLI 4.x and the unreleased 5.x `theme push --json` shapes.
- **indie-ridge's `lint.yml` reads red** on info-level SC2086 findings in its own `Feature-Deploy` and
  `Staging-Deploy` until its cutover deletes them.

## Blocked or gated

- **Up-to-date branches fleet-wide, by one org ruleset (#99).** Only workflows, indie-ridge, savannahfriedkin,
  LittleMe, Kissy-Kissy, R-Finds, driver-agents and driver-engineering-app enforce it. First confirm every targeted branch reports
  the required check; a required context with no run blocks every merge.
- **Anduril-Gear's cutover** waits on its shared kit install (Anduril-Gear #26, draft).
- **Real tickets through driver-engineering-app** wait on its security hardening pass.
- **WebSearch/WebFetch** stay off until anthropics/claude-code-action#690 is fixed. The action floats
  on `v1`, so the fix arrives on its own; then remove the caveat comment in `claude.yml`.
- **Dependabot auto-merge (#85)** on validate + report + Macroscope all clear. Let the
  `dependabot.yml` standard run for a while after its first wave. `dependabot-report` stays either way.

## Open decisions

- **#79 (ticket-assets screenshots) is tabled** until #95's Figma paragraph has run on real tickets
  (driver-agents #47 is the live test). `AGENTS_GH_PAT` can read `ticket-assets` if it is needed.
- **Shared workflows on driver-agents.** It carries a partial kit. No `dependabot-report`: its stub's
  `secrets: inherit` would hand a shared workflow driver-agents' Bonsai key, so it could qualify for
  #85 only through a stub with an explicit secrets map. Add `claude.yml` + `pr-bonsai-link.yml` only
  if tickets should reach driver-agents.
- **foundrae's `dev-staging` and `testparty/*` branches:** retire them at its cutover, or keep them.

## Watch-items

- **Dependabot on LittleMe.** Its runs from August on sat queued for 24 hours and were cancelled:
  "Dependabot on self-hosted runners" was on with no self-hosted runner. The setting is off, and
  Kissy-Kissy's and LaPointe's runs have succeeded since; LittleMe has not run since. Its next
  daily run must start and complete (`gh run list -R DriverDigital/LittleMe --event dynamic`); if it
  queues again, the cause is something else.
- **The Dependabot report** cannot name what was bumped (#113).
- **`volta.node` repos** (Avara, Kissy-Kissy, LittleMe, LaPointe, Palmers, R-Finds): CI builds on the
  pinned Node. A red implementer or validate build there is most likely the repo's own Node problem.
- **The kit-tag cooldown exemption** is unverified live. Watch vite-plugin-shopify-clean after the
  next tag.
- **`claude-standards.md` on the comment path** is unverified (the issues path loads it). Have a
  collaborator's `@claude` ask the implementer to quote the attachment header; bot comments do not
  reach it.
- **The first implementer run after the wave** must show `--model opus --advisor fable` in its log.
- **The first PR merged into a Palmers `main-*` branch after the wave.** Its `Closes #N` issue must
  close with a comment naming the PR.
- **The first real ticket through the implementer.** The guard steps should stay quiet; if one
  fires, the failure note lands on the issue and, on a private repo, the transcript is in the run log.
  On Avara the log must read `Provisioned store 'avara'` and the "Mint the store token as a log mask"
  step must pass. Never print the token cache to prove the mask.
- **Figma check-run agent spend.** It runs on PRs that touch theme or front-end paths in the pipeline
  Shopify repos, at most 4 runs a PR. A run with no design cost $0.27–$1.31 on Avara, more for bigger
  diffs; a run with a design is unmeasured (capped at $6 a run, $24 a PR).
- **A red validate on an old Dependabot PR** clears on `@dependabot rebase` or any push.
- **The first Vercel cutover.** Confirm a staged build leaves the production domain alone, including
  `<project>.vercel.app` on studio-sulzer and Team-Laird, which have no custom domain. Check whether
  a Sanity publish fires a deploy hook on any site: if one does, published content waits for a
  promotion. Confirm auto-assign stays off after the first promotion, and turn it off again after
  undoing a rollback.

## Next steps

1. Re-list the `todo` issues, then cut over LaPointe, foundrae-blackridge and Avara, in that order
   (#91, [`branch-model.md`](branch-model.md#order)), then Palmers, indie-ridge and Anduril-Gear, then
   the Vercel cutovers.
   The `repo-cutover` skill, if available, runs these step by step and resumes from
   `~/cutover/log.md`.
2. In the first release and wave after the cutovers, ship #86: one kit-owned `.nvmrc` per platform
   replaces each repo's own Node pin (`volta.node`, `engines.node`), several of them past end of life.
3. Settle the open decisions above.

## Pointers

- [`README.md`](../README.md): the pipeline, the rails, the kit, release + repin order, and
  [Macroscope on a PR](../README.md#macroscope-on-a-pr).
- [`fleet-operations.md`](fleet-operations.md): wave mechanics, what the pin audit cannot see, branch
  protection.
- [`branch-model.md`](branch-model.md): the platform standards, the topics, and the cutover runbook.
- `driver-agents`: the dispatcher, the ticket map and the canonical Shopify instructions.
- The optional `repository_dispatch` trigger for the revise loop is #98.
