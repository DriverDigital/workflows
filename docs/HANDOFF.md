# Handoff

State of play: what is in flight, blocked, open and next. Conventions and how-tos live in
[`README.md`](../README.md); the agent-facing subset is [`CLAUDE.md`](../CLAUDE.md). To-dos are the
open `todo` issues (`gh issue list --label todo`); this file points at them rather than copying them.

## In flight

- **v1.22.0 is released and waved; `fleet-pin-audit.sh --stale` reads converged.** Safe patch and
  minor npm Dependabot PRs now approve and merge themselves on private kit repos (README, *The
  Dependabot security split*). Avara#264 went through end to end: verdict check, github-actions[bot]
  approval, the merge by `driver-digital-agents`, and the `Shopify theme` push on the merge commit.
- **Docs elsewhere** describe the old behaviour: driver-onboarding#46 and plugins#62.
- **Preview link at the top of the PR description** (`shopify-theme.yml`) reaches the fleet only
  with the next release and wave. Until then, a PR on v1.22.0 still gets the line at the end.

## Blocked or gated

- **Real tickets through driver-engineering-app** wait on its security hardening pass.
- **WebSearch/WebFetch** stay off until anthropics/claude-code-action#690 is fixed. The action floats
  on `v1`, so the fix arrives on its own; then remove the caveat comment in `claude.yml`.

## Open decisions

- **npm or pnpm (#132).** Weighed on its own, not tied to the next wave.
- **#79 (ticket-assets screenshots) is tabled** until #95's Figma paragraph has run on real tickets
  (driver-agents #47 is the live test). `AGENTS_GH_PAT` can read `ticket-assets` if it is needed.
- **Macroscope's policy on public repos.** Its docs do not say whether a private policy repo serves a
  public one. Set the policy on vite-plugin-shopify-clean and open a PR touching only an ignored path
  to find out, if the public repos should share it.

## Watch-items

- **The first auto-merges on the other repos.** A grouped PR whose body Dependabot truncated, or whose
  head is a merge from "Update branch", waits for a person by design. A merge that starts no push run
  on its merge commit means `DEPENDABOT_MERGE_TOKEN` lost its org approval or its access.
- **The Node-pin to-dos** (from #86) have merged everywhere but three open PRs: Kissy-Kissy#82,
  R-Finds#55 and LittleMe#61. foundrae's `main-development` PR (#256) is also open; its theme push
  fails on that branch's own files (`.shopifyignore` lacks `assets/.vite/*`, and
  `templates/page.all_components.liquid` has a Liquid error). driver-onboarding#41 adds mise to the
  setup docs.
- **Stores at Shopify's 100-theme limit.** LittleMe hit it (LittleMe#61's push failed). While the
  CLI 5 bug was live, every closed PR's cleanup failed too, so stale `DRIVER/<branch>` themes may
  have piled up on other stores. Delete them in the admin; a push that fails on the limit clears on
  a re-run.
- **First wave of `lint.yml`** on driver-onboarding, vite-plugin-shopify-clean, plugins and
  client-workspaces: a red `actionlint` there is a finding in the repo's own workflows.
- **First PRs under the ruleset** on client-workspaces, plugins, driver-onboarding, studio-sulzer and
  driver-engineering-app, which had not run `validate / validate` on a PR yet. A PR stuck on
  "Expected" there means the stub did not start; an org admin can merge past it.
- **After the v1.21.0 wave:** the first `@claude` issue a person opens with no Bonsai task ends with a review request on its PR; the
  first implementer PR on an issue with acceptance criteria has a How to QA section after its
  Bonsai line, pointed at the right preview for the repo's platform.
- **The kit-tag cooldown exemption** is unverified live. Watch vite-plugin-shopify-clean's Dependabot
  PR for the next tag's stub pins.
- **`claude-standards.md` on the comment path** is unverified (the issues path loads it). Have a
  collaborator's `@claude` ask the implementer to quote the attachment header; bot comments do not
  reach it.
- **Team-Laird and The-Gathery on the implementer.** Team-Laird's build throws without
  `SANITY_API_READ_TOKEN`, which the implementer never gets; until Team-Laird#86 names the no-secrets
  build in its `CLAUDE.md`, say so in the `@claude` request. The-Gathery has no preview deploy, so its
  PRs carry QA steps with no preview link.
- **Palmers' `DRIVER/main-ma`** was created afresh at the cutover: the push found no unpublished theme
  of that name, though July's deploy had updated one (id 163173007417). It was deleted, renamed or
  published; check the Morocco store's admin.
- **The first real ticket through the implementer.** The guard steps should stay quiet; if one
  fires, the failure note lands on the issue and, on a private repo, the transcript is in the run log.
  On Avara the log must read `Provisioned store 'avara'` and the "Mint the store token as a log mask"
  step must pass. Never print the token cache to prove the mask.
- **Figma fidelity runs need the `figma` label.** A theme PR opened before the v1.22.0 wave keeps the
  old, unlabelled agent copy on its branch until it merges `main`. The first ticket with a design
  should show the label on its PR and one fidelity check.
- **A PR whose head is `main` or a `main-*` branch** would delete that branch's own `DRIVER/<branch>`
  theme when it closes: `shopify-theme.yml`'s cleanup deletes every non-live theme named after the
  head branch. None exists today (a foundrae `main-development` → `main` PR would be the first); the
  next push would recreate the theme under a new id.
- **A red validate on an old Dependabot PR** clears on `@dependabot rebase` or any push.

## Next steps

1. Each client repo adds its team-memory folder link to `CLAUDE.md` by hand (#145).
2. Settle the open decisions above.

## Pointers

- [`README.md`](../README.md): the pipeline, the rails, the kit, release + repin order, and
  [Macroscope on a PR](../README.md#macroscope-on-a-pr).
- [`fleet-operations.md`](fleet-operations.md): wave mechanics, what the pin audit cannot see, branch
  protection.
- [`branch-model.md`](branch-model.md): the platform standards, the topics, and the cutover runbook.
- `driver-agents`: the dispatcher, the ticket map, the canonical Shopify instructions and Macroscope's
  policy (`.macroscope/`).
- The optional `repository_dispatch` trigger for the revise loop is #98.
