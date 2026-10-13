# Handoff — 2026-10-13

State of play: what is in flight, blocked, open and next. Conventions and how-tos live in
[`README.md`](../README.md); the agent-facing subset is [`CLAUDE.md`](../CLAUDE.md). To-dos are the
open `todo` issues (`gh issue list --label todo`); this file points at them rather than copying them.

## In flight

- **Unreleased on `main`, riding the next wave:** the `templates/github/dependabot/` variants (the
  wave writes `.github/dependabot.yml` fleet-wide for the first time) and #94's validate change once
  it merges. `fleet-pin-audit.sh --stale` shows the `dependabot.yml` rows, plus driver-agents' stale
  `claude-standards.md`, until then.
- **PR #94** is approved and waits on the owner's merge. It makes `dependabot-validate` skip install
  when a repo has no root `package.json`. It touches a reusable, so it needs a tag, a repin and a wave
  (README, "Release + repin order").
- **The wave's default message names the latest tag** (`chore(kit): repin to <tag>`; the latest tag is v1.19.0).
  Pass `--message` whenever the wave runs without a new tag.
- **#62:** close it once the audit shows every target on its `dependabot.yml` variant.
- **#83:** the house-standards import PRs are open on LaPointe #149, Palmers #124,
  Driver-Digital-Website #179, studio-sulzer #65, client-workspaces #7 and Driver-Horizon #11. The repos
  without a `CLAUDE.md` each carry their own to-do. Close #83 when these land.
- **indie-ridge and savannahfriedkin** carry the shared kit on `main` (topics `driver-kit` +
  `shopify-theme`). Their Shopify cutover rides with #91. indie-ridge's own `Feature-Deploy` and
  `Staging-Deploy` carry info-level SC2086 findings, so its `lint.yml` reads red until the cutover
  deletes them.
- **Platform standards rollout (#91):** no repo carries a platform stub. Each stub arrives with
  that repo's canary, cutover or install commit ([`branch-model.md`](branch-model.md#order)).

## Blocked or gated

- **LittleMe's cutover pilot** waits on driver-agents #53 (point its map entry at `main`).
- **Driver-Horizon's cutover** waits on Driver-Horizon #10 (a theme check error).
- **Driver-Digital-Website's Vercel install** needs `VERCEL_TEAM_LOGINS` set first.
- **No wave runs while a cutover is in progress** (CLAUDE.md invariant).
- **Real tickets through driver-engineering-app** wait on its security hardening pass.
- **`.macroscope/check-run-agents/` in the wave (#61)** waits on the first real Avara design ticket to
  tune the rubric. Add the root in `dest()`, which already maps `.claude/settings.json`.
- **WebSearch/WebFetch** stay off until anthropics/claude-code-action#690 is fixed. The action floats
  on `v1`, so the fix arrives on its own; then remove the caveat comment in `claude.yml`.
- **Dependabot auto-merge (#85)** on validate + report + Macroscope all clear. Let the new
  `dependabot.yml` standard run for a while first. `dependabot-report` stays either way.

## Open decisions

- **Require branches to be up to date before merging, fleet-wide.** Every repo should, and most kit
  branches do not. Strict only bites with at least one required check: classic protection stores
  `strict` with no contexts but enforces nothing, and a ruleset's `required_status_checks` rule needs
  at least one check. Today only workflows, indie-ridge, driver-agents and driver-engineering-app
  enforce it. Decide between an org ruleset (no org rulesets exist; it adds to classic protection, and
  repos without the shared check block until they carry it) and per-repo `PATCH`es
  ([`fleet-operations.md`](fleet-operations.md#branch-protection)).
- **Shared workflows on driver-agents.** It carries a partial kit, for separation of concerns only.
  Recommendation: add `dependabot-report` so its Dependabot PRs can qualify for #85 auto-merge. Add
  `claude.yml` + `pr-bonsai-link.yml` only if tickets should reach driver-agents.
- **foundrae's `dev-staging` and `testparty/06-2026`:** retire them at its cutover, or keep them.

## Watch-items

- **The first `shopify-theme.yml` canary** (savannahfriedkin). Every repo but Palmers takes the
  `environment: ''` arm of the push and cleanup jobs. Read the push job log first: the job must run
  with no environment, and `vars.` must resolve in `jobs.<id>.environment`. If either fails, split the
  job into two variants rather than documenting around it.
- **The first fleet-wide `dependabot.yml` wave.** Canary it with `--only` on one npm repo: each npm
  repo gets a burst of single-major PRs (capped at 5 open), each with a validate run and a Macroscope
  review. driver-engineering-app, client-workspaces and plugins get Dependabot for the first time, and
  none of the three has validate or report rails, so their PRs arrive unchecked. The `actions/*`
  minor/patch ignore also stops patch bumps on exact-pinned repo workflows (the pre-cutover deploy
  workflows; vite-plugin-shopify-clean #120).
- **`volta.node` repos** (Avara, Kissy-Kissy, LittleMe, LaPointe, Palmers, R-Finds): CI builds on the pinned
  Node. A red implementer or validate build there is most likely the repo's own Node problem.
- **The kit-tag cooldown exemption** is unverified live. Watch vite-plugin-shopify-clean after the
  next tag.
- **`claude-standards.md` on the comment path** is unverified (the issues path loads it). Have a
  collaborator's `@claude` ask the implementer to quote the attachment header; bot comments do not
  reach it.
- **The first real ticket on the current implementer.** The guard steps should stay quiet; if one
  fires, the failure note lands on the issue and, on a private repo, the transcript is in the run log.
  On Avara the log must read `Provisioned store 'avara'` and the "Mint the store token as a log mask"
  step must pass. Never print the token cache to prove the mask.
- **A red validate on an old Dependabot PR** clears on `@dependabot rebase` or any push.

## Next steps

1. Merge #94 (owner), then tag, repin and wave (README, "Release + repin order"). Canary the wave
   with `--only` first (watch-items), then run `fleet-pin-audit.sh --stale` until it reads converged.
2. After that wave, comment `@dependabot rebase` on indie-ridge #3 and #4 and savannahfriedkin #18.
   A wave is a direct push, not a merged PR, so keep-current never runs for it.
3. Roll out the platform standards (#91, [`branch-model.md`](branch-model.md#order)): canary
   savannahfriedkin's stub, pilot LittleMe once unblocked, then the remaining cutovers one at a time,
   then the Vercel installs.
4. Settle the open decisions above.

## Pointers

- [`README.md`](../README.md): the pipeline, the rails, the kit, release + repin order, and
  [Macroscope on a PR](../README.md#macroscope-on-a-pr).
- [`fleet-operations.md`](fleet-operations.md): wave mechanics, what the pin audit cannot see, branch
  protection.
- [`branch-model.md`](branch-model.md): the platform standards, the topics, the Shopify cutover and
  Vercel install runbooks.
- `driver-agents`: the dispatcher, the ticket map and the canonical Shopify instructions. On a
  multi-branch repo (Palmers) the client identifies the branch and the dispatcher infers it from the
  map; a `branch:` line on a ticket is optional (driver-agents #62 aligns its docs).
- The optional `repository_dispatch` trigger for the revise loop is #98.
