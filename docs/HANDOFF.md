# Handoff

State of play: what is in flight, blocked, open and next. Conventions and how-tos live in
[`README.md`](../README.md); the agent-facing subset is [`CLAUDE.md`](../CLAUDE.md). To-dos are the
open `todo` issues (`gh issue list --label todo`); this file points at them rather than copying them.

## In flight

- **v1.20.0 is released and waved; `fleet-pin-audit.sh --stale` reads converged.** Every site repo
  is cut over to `main`.
  - The wave and the pin audit cover every `main-*` branch of a repo already on `main`, so
    foundrae's `main-development` takes kit updates like Palmers' country branches.
  - A `shopify-theme.yml` stub copied from an older template fails at startup (the push job needs
    `pull-requests: write`).
- **The next release and wave.** Work through this list over as many sessions as it takes, then
  release and wave (README, *Release + repin order*). Tick an item in the PR that lands it.
  - [x] #120 (merged): #113 (the Dependabot report names each bump), #115 and #119 (the theme push
    job fails on rejected files, reading Shopify CLI 4.x and the unreleased 5.x output) and #118 (a
    reviewer request on no-ticket issue runs).
  - [x] #126 (merged): How to QA steps in implementer PR bodies.
  - [x] #128, #124, #121, #127: keep-current's author filter, the Shopify CLI error on a failed theme
    list, code fences in `close-linked-issues.yml`, the PR template's bonsai-link sentence.
  - [x] Standards: docs ship in the same PR as the change; PR comments @mention the author; one
    closing keyword per issue. Kit only, so the wave carries it without the tag.
  - [x] The no-task reviewer request warns when it cannot read `reviewers.json`.
  - [x] #122: no preview theme for a PR that changes no theme files.
  - [x] #86: the kit owns each platform's Node major as a root `.node-version` (`24`). Until the
    wave, `fleet-pin-audit.sh` reads `.node-version DRIFT missing` on every platform repo.
  - [x] #135: kit tiers. Every `driver-kit` repo takes the standards, private repos the private
    files, private repos with `agents-pipeline` the implementer; the wave adds missing files by tier,
    blocks on a file above a repo's tier, and the reusable `claude.yml` refuses a public repo.
  - [ ] Before the kit-tiers PR merges: add `DRIVER_AGENTS_READ_TOKEN` to this repo (a fine-grained
    token, Contents read on driver-agents only). Until it exists the blockquote check fails on every
    PR but Dependabot's.
  - [ ] Before the wave, or it blocks: put `agents-pipeline` on each private repo that takes Bonsai
    tickets. Fourteen private repos carry `claude.yml` today, and each one left without the topic
    blocks the wave: the ten Shopify repos, studio-sulzer, Driver-Digital-Website, plugins and
    client-workspaces. Decide which of the last four stay on the pipeline; any that leave need a PR
    removing `claude.yml`. vite-plugin-shopify-clean is public and must never carry the topic, which
    blocks the wave outright.
  - [ ] Before the wave, or it blocks: merge the vite-plugin-shopify-clean PR that removes
    `claude.yml`, `pr-bonsai-link.yml`, the PR template, `dependabot-report.yml` and
    `dependabot-keep-current.yml`.
  - [ ] #130: the fleet audit, last before the wave. studio-sulzer#81 (`engines.node`) can land any
    time and should, or the pin audit stays red after the wave.
  - Next release, not this one: #129, then #85 (make the Dependabot verdict a real check, then
    auto-merge on it), in their own session.
  - Not tied to the release: #99 (the up-to-date org ruleset). Only workflows, indie-ridge,
    savannahfriedkin, LittleMe, Kissy-Kissy, R-Finds, LaPointe, foundrae-blackridge, Anduril-Gear,
    Avara, Palmers (every `main*` branch), Team-Laird, studio-sulzer, The-Gathery, driver-agents and
    driver-engineering-app enforce it today. First confirm every targeted branch reports the
    required check; a required context with no run blocks every merge.
- **Switch the org secrets to private repositories** once the vite-plugin-shopify-clean PR and the
  kit-tiers PR have merged, so no public repo uses them and this repo reads its own token. Set
  `CLAUDE_CODE_OAUTH_TOKEN`, `AGENTS_GH_PAT`, `FIGMA_MCP_SECRET` and `SHOPIFY_ALERT_WEBHOOK` to
  "Private repositories" in the org's Actions secrets. Then update README's org-secrets paragraph and
  the kit README's install step 2, which say every repo.

## Blocked or gated

- **Real tickets through driver-engineering-app** wait on its security hardening pass.
- **WebSearch/WebFetch** stay off until anthropics/claude-code-action#690 is fixed. The action floats
  on `v1`, so the fix arrives on its own; then remove the caveat comment in `claude.yml`.

## Open decisions

- **npm or pnpm (#132).** Weighed on its own, not tied to the next wave.
- **#79 (ticket-assets screenshots) is tabled** until #95's Figma paragraph has run on real tickets
  (driver-agents #47 is the live test). `AGENTS_GH_PAT` can read `ticket-assets` if it is needed.

## Watch-items

- **Dependabot on LittleMe.** Its runs from August on sat queued for 24 hours and were cancelled:
  "Dependabot on self-hosted runners" was on with no self-hosted runner. The setting is off, and
  Kissy-Kissy's and LaPointe's runs have succeeded since; LittleMe has not run since. Its next
  daily run must start and complete (`gh run list -R DriverDigital/LittleMe --event dynamic`); if it
  queues again, the cause is something else.
- **After the next release's wave** (stubs past v1.20.0, whose reusables read `.node-version`): each
  repo's `todo` to drop its Volta pin, stray `.nvmrc` or Shopify `engines.node` (from #86) can land.
  Before then, removing a pin leaves CI on the runner default.
  driver-onboarding#41 adds mise to the setup docs.
- **The next wave adds files by tier for the first time.** It adds `lint.yml` to driver-onboarding,
  vite-plugin-shopify-clean, plugins and client-workspaces, and a repo whose own workflows have
  findings shows a red `actionlint` until they are fixed. It adds the PR template and `bonsai-link`
  to driver-agents, driver-onboarding, driver-engineering-app, Team-Laird and The-Gathery, so a PR
  there reads red until its `Bonsai task:` line is filled. It adds the Dependabot stubs to plugins,
  client-workspaces, studio-sulzer and driver-engineering-app, `dependabot-report` to driver-agents,
  and `.github/dependabot.yml` with all three stubs to driver-onboarding. Read the dry run before it.
- **After the next release and wave:** the first Dependabot report names each package with its from
  and to versions; the first file Shopify rejects fails `theme / push` with a file annotation; the
  first `@claude` issue a person opens with no Bonsai task ends with a review request on its PR; the
  first implementer PR on an issue with acceptance criteria has a How to QA section after its
  Bonsai line, pointed at the right preview for the repo's platform.
- **`volta.node` repos** (Avara, Kissy-Kissy, LittleMe, LaPointe, Palmers, R-Finds, The-Gathery): CI
  builds on the pinned Node until the next release's wave, then on the kit's `.node-version`. A red
  implementer or validate build there is most likely the repo's own Node problem.
- **The kit-tag cooldown exemption** is unverified live. Watch vite-plugin-shopify-clean after the
  next tag.
- **`claude-standards.md` on the comment path** is unverified (the issues path loads it). Have a
  collaborator's `@claude` ask the implementer to quote the attachment header; bot comments do not
  reach it.
- **The first implementer run after the wave** must show `--model opus --advisor fable` in its log.
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

1. Work through the release list under *In flight*, one feature branch and draft PR per session.
2. Release and wave once it is done. driver-agents #80 then updates its README to match #120.
3. Settle the open decisions above.

## Pointers

- [`README.md`](../README.md): the pipeline, the rails, the kit, release + repin order, and
  [Macroscope on a PR](../README.md#macroscope-on-a-pr).
- [`fleet-operations.md`](fleet-operations.md): wave mechanics, what the pin audit cannot see, branch
  protection.
- [`branch-model.md`](branch-model.md): the platform standards, the topics, and the cutover runbook.
- `driver-agents`: the dispatcher, the ticket map and the canonical Shopify instructions.
- The optional `repository_dispatch` trigger for the revise loop is #98.
