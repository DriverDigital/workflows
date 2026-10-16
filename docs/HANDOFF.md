# Handoff

State of play: what is in flight, blocked, open and next. Conventions and how-tos live in
[`README.md`](../README.md); the agent-facing subset is [`CLAUDE.md`](../CLAUDE.md). To-dos are the
open `todo` issues (`gh issue list --label todo`); this file points at them rather than copying them.

## In flight

- **v1.20.0 is released and waved; `fleet-pin-audit.sh --stale` reads converged.** The cutovers
  (#91) are under way: savannahfriedkin is done, LittleMe is next.
  - Every other Shopify default branch still lacks the `shopify-theme.yml` stub until its cutover,
    so draft-PR previews and the description link start per repo then. A stub copied from an
    older template fails at startup (the push job needs `pull-requests: write`).
- **indie-ridge's `lint.yml` reads red** on info-level SC2086 findings in its own `Feature-Deploy` and
  `Staging-Deploy` until its cutover deletes them.

## Blocked or gated

- **Up-to-date branches fleet-wide, by one org ruleset (#99).** Only workflows, indie-ridge, savannahfriedkin,
  driver-agents and driver-engineering-app enforce it. First confirm every targeted branch reports
  the required check; a required context with no run blocks every merge.
- **R-Finds' and Anduril-Gear's cutovers** wait on their shared kit install.
- **#83** waits on Kissy-Kissy and LittleMe, which have no `CLAUDE.md` to carry the import; the
  cutover commit adds the import only to an existing one.
- **Real tickets through driver-engineering-app** wait on its security hardening pass.
- **WebSearch/WebFetch** stay off until anthropics/claude-code-action#690 is fixed. The action floats
  on `v1`, so the fix arrives on its own; then remove the caveat comment in `claude.yml`.
- **Dependabot auto-merge (#85)** on validate + report + Macroscope all clear. Let the
  `dependabot.yml` standard run for a while after its first wave. `dependabot-report` stays either way.

## Open decisions

- **#79 (ticket-assets screenshots) is tabled** until #95's Figma paragraph has run on real tickets
  (driver-agents #47 is the live test). `AGENTS_GH_PAT` can read `ticket-assets` if it is needed.
- **#86 (one `.nvmrc` per platform) is tabled** and ships in its own PR when it goes ahead.
- **Shared workflows on driver-agents.** It carries a partial kit. No `dependabot-report`: its stub's
  `secrets: inherit` would hand a shared workflow driver-agents' Bonsai key, so it could qualify for
  #85 only through a stub with an explicit secrets map. Add `claude.yml` + `pr-bonsai-link.yml` only
  if tickets should reach driver-agents.
- **foundrae's `dev-staging` and `testparty/*` branches:** retire them at its cutover, or keep them.

## Watch-items

- **Dependabot on LittleMe, Kissy-Kissy and LaPointe.** Every run there from August on sat queued
  for 24 hours and was cancelled: "Dependabot on self-hosted runners" was on with no self-hosted
  runner. The setting is now off on all three. The next daily `github_actions` run must start and
  complete (`gh run list -R DriverDigital/<repo> --event dynamic`); if it queues again, the cause
  is something else.
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

1. Re-list the `todo` issues, then cut over LittleMe (#91, [`branch-model.md`](branch-model.md#order)),
   then the remaining Shopify cutovers one at a time, then the Vercel cutovers.
2. Settle the open decisions above.

## Pointers

- [`README.md`](../README.md): the pipeline, the rails, the kit, release + repin order, and
  [Macroscope on a PR](../README.md#macroscope-on-a-pr).
- [`fleet-operations.md`](fleet-operations.md): wave mechanics, what the pin audit cannot see, branch
  protection.
- [`branch-model.md`](branch-model.md): the platform standards, the topics, and the cutover runbook.
- `driver-agents`: the dispatcher, the ticket map and the canonical Shopify instructions.
- The optional `repository_dispatch` trigger for the revise loop is #98.
