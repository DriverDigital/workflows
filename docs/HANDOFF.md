# Handoff

State of play: what is in flight, blocked, open and next. Conventions and how-tos live in
[`README.md`](../README.md); the agent-facing subset is [`CLAUDE.md`](../CLAUDE.md). To-dos are the
open `todo` issues (`gh issue list --label todo`); this file points at them rather than copying them.

## In flight

- **v1.20.0 is released and waved; `fleet-pin-audit.sh --stale` reads converged.** The cutovers
  (#91) are under way: savannahfriedkin, LittleMe, Kissy-Kissy, R-Finds, LaPointe and
  foundrae-blackridge are done.
  - The wave and the pin audit cover every `main-*` branch of a repo already on `main`, so
    foundrae's `main-development` takes kit updates like Palmers' country branches.
  - Step 6's commit now rewrites the repo's own README and CLAUDE.md; every repo cut over so
    far is done.
  - Every other Shopify default branch still lacks the `shopify-theme.yml` stub until its cutover,
    so draft-PR previews and the description link start per repo then. A stub copied from an
    older template fails at startup (the push job needs `pull-requests: write`).
- **#120 is merged, not released.** It carries #113 (the Dependabot report names each bump), #115
  and #119 (the theme push job fails on rejected files, reading Shopify CLI 4.x and the unreleased
  5.x output) and #118 (a reviewer request on no-ticket issue runs). The reusables change, so it
  reaches the fleet only with a release and wave.
- **indie-ridge's `lint.yml` reads red** on info-level SC2086 findings in its own `Feature-Deploy` and
  `Staging-Deploy` until its cutover deletes them.
- **`lint.yml` goes on every kit repo.** Step 6 adds it at each cutover, and every repo cut over so
  far carries it. The-Gathery, driver-onboarding, vite-plugin-shopify-clean, plugins and
  client-workspaces get no step-6 commit and still lack it.

## Blocked or gated

- **Up-to-date branches fleet-wide, by one org ruleset (#99).** Only workflows, indie-ridge, savannahfriedkin,
  LittleMe, Kissy-Kissy, R-Finds, LaPointe, foundrae-blackridge, driver-agents and driver-engineering-app enforce it. First confirm every targeted branch reports
  the required check; a required context with no run blocks every merge.
- **Real tickets through driver-engineering-app** wait on its security hardening pass.
- **WebSearch/WebFetch** stay off until anthropics/claude-code-action#690 is fixed. The action floats
  on `v1`, so the fix arrives on its own; then remove the caveat comment in `claude.yml`.
- **Dependabot auto-merge (#85)** on validate + report + Macroscope all clear. Let the
  `dependabot.yml` standard run for a while after its first wave. `dependabot-report` stays either way.

## Open decisions

- **#79 (ticket-assets screenshots) is tabled** until #95's Figma paragraph has run on real tickets
  (driver-agents #47 is the live test). `AGENTS_GH_PAT` can read `ticket-assets` if it is needed.

## Watch-items

- **Dependabot on LittleMe.** Its runs from August on sat queued for 24 hours and were cancelled:
  "Dependabot on self-hosted runners" was on with no self-hosted runner. The setting is off, and
  Kissy-Kissy's and LaPointe's runs have succeeded since; LittleMe has not run since. Its next
  daily run must start and complete (`gh run list -R DriverDigital/LittleMe --event dynamic`); if it
  queues again, the cause is something else.
- **After #120's release and wave:** the first Dependabot report names each package with its from
  and to versions; the first file Shopify rejects fails `theme / push` with a file annotation; the
  first `@claude` issue a person opens with no Bonsai task ends with a review request on its PR.
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

All cutovers land before the next release and wave.

1. Re-list the `todo` issues, then cut over Avara
   (#91, [`branch-model.md`](branch-model.md#order)), then Palmers, indie-ridge and Anduril-Gear, then
   the Vercel cutovers.
   The `repo-cutover` skill, if available, runs these step by step and resumes from
   `~/cutover/log.md`.
2. Work through the open `todo` issues; what lands ships in the next release.
3. Release and wave (README, *Release + repin order*): #120, #86 (one kit-owned `.nvmrc` per
   platform replaces each repo's own Node pin, several of them past end of life) and step 2's work.
   driver-agents #80 then updates its README to match #120.
4. Settle the open decisions above.

## Pointers

- [`README.md`](../README.md): the pipeline, the rails, the kit, release + repin order, and
  [Macroscope on a PR](../README.md#macroscope-on-a-pr).
- [`fleet-operations.md`](fleet-operations.md): wave mechanics, what the pin audit cannot see, branch
  protection.
- [`branch-model.md`](branch-model.md): the platform standards, the topics, and the cutover runbook.
- `driver-agents`: the dispatcher, the ticket map and the canonical Shopify instructions.
- The optional `repository_dispatch` trigger for the revise loop is #98.
