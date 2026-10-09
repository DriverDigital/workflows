# Handoff — 2026-10-09

State of play for the next session. Conventions, how-tos and release history live in
[`README.md`](../README.md); the agent-facing subset is [`CLAUDE.md`](../CLAUDE.md).

## Where things stand

2026-10-09: **v1.19.0 is released and waved** (#87; 22 targets, then driver-agents as the 23rd once
the wave found branches by `lint.yml`; the audit reads converged). Maria trains the engineering team
on these SOPs at the end of the week of 2026-10-12; the rollout below is not time-sensitive, but a
canary and one cutover done before then give the training a working example. **Two platform standards** ([`branch-model.md`](branch-model.md)); no repo carries a
platform stub yet, since each arrives with the repo's canary, cutover or install commit. Shopify sites go to `main` only (Palmers: `main` + `main-*`)
and take the `shopify-theme.yml` reusable (#80, #82). Vercel sites keep `develop` + `main` and take
`vercel-deploy.yml`. Repos opt in with the `driver-kit` topic, and `shopify-theme` / `vercel-site` /
`wordpress-site` pick the platform files (WordPress has none yet). The topics are set on all 20 kit
repos (2026-10-09; the list is in [`branch-model.md`](branch-model.md#which-repos-get-what)), and a
dry-run wave with the branch's tools finds 22 targets and no blocks. The wave writes only to enrolled
repos and only their own platform's files; the audit reports a platform file on the wrong repo as
drift and lists unenrolled repos' kit files apart, never failing on them. In the same release: the Dependabot
house standard (#62), each repo's pinned Node in CI (#75, #77), Closes lines (#76), the
`CLAUDE.local.md` rule (#78) and `.claude/settings.json` (#83). **Decided: `dependabot-report` stays**
(Maria, 2026-10-09). It, validate and Macroscope together are what make a clear Dependabot PR safe to
merge unread; auto-merge on all three is #85. One Node version per platform (a kit `.nvmrc`) is #86.

2026-10-01, later: **v1.18.0 is released and waved** (22 targets, converged): the validator fix (#73 —
every clean Dependabot PR had carried a red required check since v1.15.0), the implementer prompt's
comments item (#74), the subagents rule (#72), plus the kit-only changes since v1.17.0. Canary and
audit: [`README.md`](../README.md#v1180-85f1578-2026-10-01). driver-onboarding is a wave target for
`claude-standards.md` only.

2026-10-01: **v1.17.0 is released and waved.** `claude.yml` is a reusable + thin stub (#60), the canary
on vite-plugin-shopify-clean passed every assertion in [`claude-yml-wave-plan.md`](claude-yml-wave-plan.md)
"Running it", all 21 targets are on the tag, and the audit reads converged (driver-agents' hand-installed `lint.yml`,
outside the wave, was re-copied by hand the same night, `ed2ad6a`). Release record and what is not yet
proven: [`README.md`](../README.md#v1170-359505a-2026-10-01).

To-dos are the open `todo` issues on this repo since 2026-10-01 (#61–#64 carry the former
`CLAUDE.local.md` items).

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

- **foundrae's `dev-staging` and `testparty/06-2026`:** retire at its cutover or keep.

## Watch-items

- **`shopify-theme.yml`'s first canary** (savannahfriedkin): every repo but Palmers takes the
  `environment: ''` arm of the push and cleanup jobs. Read the push job log first: it must run with no
  environment, and `vars.` must resolve in `jobs.<id>.environment`. If either fails, split the job
  into two variants rather than documenting around it.

- **Dependabot PRs opened before v1.18.0** still show the old red validate on their current head; a
  `@dependabot rebase` or any push gets a fresh run. Nothing to do fleet-wide; they clear as they move.
- **The first real ticket through v1.19.0.** The guard steps should stay quiet; if one fires, the
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

0. **#89 first: wave `dependabot.yml` as whole-file variants** (actions only, actions + npm, and
   vite-plugin-shopify-clean's own). Land it before the cutovers and installs, so their commits carry
   no hand-written `dependabot.yml`; the wave installs it instead. It closes #62 once every enrolled
   repo is on a variant. Kit-only, so it rides the next release.
1. **Roll out the platform standards** (#91; `branch-model.md` → "Order", from step 4):
   - canary the `shopify-theme.yml` stub on savannahfriedkin and read its push job log (watch-items);
   - pilot the Shopify cutover on LittleMe once driver-agents #53 points its map entry at `main`, then
     the rest one at a time (Driver-Horizon waits on Driver-Horizon #10, a theme check error);
   - the Vercel installs (Driver-Digital-Website needs `VERCEL_TEAM_LOGINS` first).
   No wave runs while a cutover is in progress.
2. **Watch the first implementer and Dependabot validate runs on a `volta.node` repo** (Avara,
   Kissy-Kissy, LittleMe, LaPointe, Palmers): CI now builds on the pinned Node, not 22, so a red build
   there is most likely the repo's own Node problem surfacing.
3. **One real ticket end to end** on the new rail, transcript read (private repos log it) — after
   driver-engineering-app's security hardening pass (Maria, 2026-10-01: a couple of weeks; she will
   not run tickets through the app before it). On Avara, the first store run's log must read
   `Provisioned store 'avara'` and the "Mint the store token as a log mask" step must pass — never
   print the token cache to prove the mask.
4. **`fleet-wave.sh` gains `.macroscope/check-run-agents/`** (#61) — after the first real Avara design
   ticket tunes the rubric (driver-agents #32 holds the prompt; Avara's copy merged 2026-09-29). The
   `dest()` helper is where another root goes (it already maps `.claude/settings.json`).

## Pointers

- [`README.md`](../README.md) — release + repin order, what's in the kit, dated release history.
- [`fleet-operations.md`](fleet-operations.md) — wave mechanics, the fleet counts, what the pin audit
  cannot see, branch protection.
- [`branch-model.md`](branch-model.md) — the two platform standards, the topics, and the Shopify
  cutover and Vercel install runbooks.
- [`claude-yml-wave-plan.md`](claude-yml-wave-plan.md) — the v1.17.0 implementer wave (shipped); its
  two gated items (WebSearch/WebFetch, `repository_dispatch`) are still open.
- [`macroscope-integration-scope.md`](macroscope-integration-scope.md) — the 2026-09-12 decision that
  Macroscope owns automatic review, and the driver-agents loop that replaced the review rails. Observed 2026-09-10: it re-reviews every push,
  resolves its own threads once a push addresses them, and its verdict reads `Approved at <sha>`
  once nothing is left; a fleet-changing kit release gets "not approved" on risk with zero findings.
- `driver-agents` — the dispatcher (since 2026-09-10) and the box-retirement spec.
