# Handoff

State of play: what is in flight, blocked, open and next. Conventions and how-tos live in
[`README.md`](../README.md); the agent-facing subset is [`CLAUDE.md`](../CLAUDE.md). To-dos are the
open `todo` issues (`gh issue list --label todo`); this file points at them rather than copying them.

## In flight

- **Unreleased since v1.19.0, riding the next tag and wave** (the next session runs it):
  - Reusables: `vercel-deploy` fires only the `main` hook; `dependabot-validate` skips install
    without a root `package.json`; the implementer `claude.yml` runs `--model opus --advisor fable`
    with subagent model tiers, clones driver-agents `main`, and its prompt now says when to read
    Figma and lists three Shopify theme traps; `shopify-theme` pushes the preview theme for draft PRs
    too and uses `actions/download-artifact@v8`.
  - Kit: `shopify-tool-smoke.yml` clones driver-agents `main`; the `shopify-theme.yml` stub drops
    the `ready_for_review` and `converted_to_draft` triggers; the new `close-linked-issues.yml`,
    installed wherever `claude.yml` is; the `templates/github/dependabot/` variants; and in
    `claude-standards.md`, the draft-first PR rule, the `docs/HANDOFF.md` rule and the theme-editor
    pull-back rule.
  - Wave: installs `figma-design-fidelity-shopify.md` on the Shopify repos with `claude.yml`, deletes
    `figma-design-fidelity.md` from Avara, and deletes the unused production theme deploy from
    Avara's and LaPointe's default branch.
  - Until then, `fleet-pin-audit.sh --stale` reports `claude-standards.md` and `dependabot.yml` drift
    fleet-wide, the Figma agent missing on the Shopify repos, and Avara's `shopify-tool-smoke.yml`.
- **indie-ridge's `lint.yml` reads red** on info-level SC2086 findings in its own `Feature-Deploy` and
  `Staging-Deploy` until its cutover deletes them.

## Blocked or gated

- **Up-to-date branches fleet-wide, by one org ruleset (#99).** Only workflows, indie-ridge,
  driver-agents and driver-engineering-app enforce it. First confirm every targeted branch reports
  the required check; a required context with no run blocks every merge.
- **The Vercel cutovers** wait on the release that carries the main-only `vercel-deploy` reusable.
- **Driver-Horizon's cutover** waits on Driver-Horizon #10 (a theme check error).
- **R-Finds' cutover** waits on its shared kit install.
- **#83** waits on the house-standards import PRs: LaPointe #149, Palmers #124,
  Driver-Digital-Website #179, studio-sulzer #65, client-workspaces #7 and Driver-Horizon #11.
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

- **The first `shopify-theme.yml` canary** (savannahfriedkin). Open it as a draft PR: a draft now
  pushes its preview theme, and marking it ready must not create a second theme. Every repo but Palmers (and foundrae,
  if its cutover sets `SHOPIFY_ENVIRONMENT_PER_BRANCH`) takes the `environment: ''` arm of the push
  and cleanup jobs. Read the push job log first: the job must run with no environment, and `vars.`
  must resolve in `jobs.<id>.environment`. If either fails, split the job into two variants rather
  than documenting around it.
- **The first fleet-wide `dependabot.yml` wave.** Canary it with `--only` on one npm repo: each npm
  repo gets a burst of single-major PRs (capped at 5 open), each with a validate run and a Macroscope
  review. driver-engineering-app, client-workspaces and plugins get Dependabot for the first time, and
  none of the three has validate or report rails, so their PRs arrive unchecked. The `actions/*`
  minor/patch ignore also stops patch bumps on exact-pinned repo workflows (the pre-cutover deploy
  workflows; vite-plugin-shopify-clean #120).
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

1. Tag, repin and wave (README, "Release + repin order"). Canary the wave with `--only` first
   (watch-items), then run `fleet-pin-audit.sh --stale` until it reads converged, and close #62.
2. After that wave, comment `@dependabot rebase` on indie-ridge #3 and #4 and savannahfriedkin #18.
   A wave is a direct push, not a merged PR, so keep-current never runs for it.
3. Roll out the platform standards (#91, [`branch-model.md`](branch-model.md#order)): canary
   savannahfriedkin's stub, pilot LittleMe, then the remaining Shopify cutovers one at a time,
   then the Vercel cutovers.
4. Settle the open decisions above.

## Pointers

- [`README.md`](../README.md): the pipeline, the rails, the kit, release + repin order, and
  [Macroscope on a PR](../README.md#macroscope-on-a-pr).
- [`fleet-operations.md`](fleet-operations.md): wave mechanics, what the pin audit cannot see, branch
  protection.
- [`branch-model.md`](branch-model.md): the platform standards, the topics, and the cutover runbook.
- `driver-agents`: the dispatcher, the ticket map and the canonical Shopify instructions.
- The optional `repository_dispatch` trigger for the revise loop is #98.
