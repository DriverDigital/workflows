# Scope: drop the Claude App, unify the GitHub surface on `driver-digital-agents`

**Status:** scoped, not started. **Written:** 2026-07-31, against `main` @ `9b70acf` (tag `v1.6.0`).
**Decision made:** the GitHub agent stays in GitHub Actions. Only the identity underneath it changes.
Nothing moves to a server. A Slack agent is a separate entity, explicitly out of scope.

---

## Goal

Humans on the team interact with **one** entity. `driver-digital-agents` is a real account — it can be
genuinely `@mentioned` (a real GitHub mention to a real account, unlike `@claude`, which only works because
the action greps for the literal string), it has an avatar, and its activity is visible. That is a real
difference in kind, not decoration.

Dropping the App also deletes the OIDC App-token-exchange path, which was the single unknown gating
[`reusable-conversion-scope.md`](reusable-conversion-scope.md).

---

## Read this first: the one finding that argues against

**Aggregate GitHub API ceiling drops roughly 58–61%, and the comment budget halves.**

DriverDigital is on the **Team** plan (not Enterprise Cloud; verified via `gh api /orgs/DriverDigital`). The
Claude App is installed org-wide across 57 repos, giving its installation token roughly **6,850–7,850 req/hr**
(5,000 base + 50/repo above 20, capped at 12,500). A user PAT is a **flat 5,000/hr** with no scaling — and
critically it is **per-account, not per-token**, so the proposed two-PAT split does *not* buy two buckets.

Worse is the secondary limit: **500 content-generating requests per hour**, also keyed on the *account* (it
counts web-UI actions too, which is the tell). Today `claude[bot]` and `driver-digital-agents` have
independent 500/hr buckets. After unification they share one.

Order of magnitude: a full ticketed cycle is roughly 30–60 content operations (tracking comment, branch
create, PR create, sentinel, plus 5–15 inline findings per review pass across up to 3 passes). **If 40 runs
complete a full cycle within an hour, that is 1,200–2,400 content ops against a 500/hr ceiling on one
account.** The 141-run wave on 2026-07-31 is not a hypothetical.

**Mitigations, in order of value:**
1. **Move every read that does not need the machine-user identity onto `github.token`** — a separate
   **1,000/hr *per repository*** bucket, so across 21 targets that is ~21,000 req/hr of free capacity going
   unused today. Concretely: `ticketed-review.yml:63,126` and `pr-first-review.yml:78` are pure reads.
2. **Measure before committing.** Add a step to one `claude.yml` and one `ticketed-review` run that hits
   `GET /rate_limit` at job start and end and echoes `x-ratelimit-used` — that endpoint does not count against
   the limit. Multiply by wave size.
3. Add 403/429 retry-with-backoff on every `gh` **write**. Today `ghj()` (`ticketed-review.yml:72-79`) retries
   reads only, and `gh pr comment` at `:260`/`:285` has no retry at all — a secondary-limit 403 there stalls
   the loop silently.
4. Prefer `--edit-last --create-if-none` over new comments.
5. Have the orchestrator throttle issue creation so a wave spreads across hours.

**This is the one finding that could reasonably change the decision. Weigh it before Phase 1.**

---

## Confirmed working — verified in the action source, not inferred

Read at pinned SHA `be7b93b1907a4abad570368f3c74b6fe3807510b`.

- **`github_token` short-circuits OIDC entirely.** `setupGitHubToken()` (`src/github/token.ts:158-165`)
  returns `OVERRIDE_GITHUB_TOKEN` before `getOidcToken()` is ever called. So `id-token: write`
  (`claude.yml:118`) is droppable, the `Revoke app token` step self-skips, and
  `workflow_not_found_on_default_branch` becomes unreachable.
- **Tag mode survives intact.** The tracking comment (`create-initial.ts:77`) is a plain `issues.createComment`
  on the supplied token; the final response is the model editing that comment via the comment MCP server,
  which is handed `GITHUB_TOKEN: githubToken`. Nothing is keyed on the actor being an App.
- **`allowed_bots` is dead-but-harmless**, settled from source: `actor.ts:84-87` never reads the list when the
  actor is a `User`. Remove `ticketed-review.yml:199` as cleanup, not as a fix.
- **The inline-comment MCP works with a PAT** — already proven in production, since both review rails pass
  `AGENTS_GH_PAT` as `github_token` today and post successfully.
- **Cascade holds.** GitHub suppresses only events made with the default `GITHUB_TOKEN`; PAT-made events
  trigger workflows. Neither review stub subscribes to `synchronize`, so the now-cascading PAT push adds no
  duplicate round.
- **`@driver-digital-agents` compiles as a trigger phrase** — `escapeRegExp` leaves `-` alone, and the mention
  appears literally in `comment.body`.

**One trap:** `use_sticky_comment` hardcodes bot id `209825114` and a `type === "Bot" && login includes
"claude"` match. We do not set it (default false). **Never enable it after the switch.**

---

## The five silent-failure risks

Every one of these fails **green**. That is the house failure mode (foundrae #148) and the reason this scope
exists.

### 1. Ticketed PRs would be reviewed by nobody

`templates/github/ticketed-review.yml:38` gates round 1 on `pull_request.user.login == 'claude[bot]'`. A
PAT-authored PR fails it, so the reusable is **never invoked** — no check run, no log. The PR then reaches
`pr-first-review`, whose `!= 'claude[bot]'` guard now *passes*, but its `has_ticket` step finds the Bonsai uuid
and skips. **Both rails end green having done nothing.**

> This corrects [`reusable-conversion-scope.md`](reusable-conversion-scope.md), which states such PRs would
> "route to the PR-first rail". They route to **nothing**, which is worse.

**Fix:** dual-accept both logins in the stub for one release wave so in-flight `claude[bot]` PRs keep their
revise loop mid-cutover, then drop the old literal. Pair the login with the immutable id `261291955`.

### 2. Commit attribution stays wrong unless set explicitly

`bot_id`/`bot_name` are **not** derived from the token, and their default is `github-actions[bot]` — not even
`claude[bot]`. Left alone, every implementer commit is misattributed. Set
`bot_name: driver-digital-agents`, `bot_id: "261291955"`.

### 3. Trigger-phrase mismatch is the #148 signature exactly

If the workflow gate accepts `@claude` while `trigger_phrase` is `@driver-digital-agents`, the job starts, tag
mode is selected, `checkContainsTrigger` returns false, and `run.ts:212` logs "No trigger found" and returns
**success without posting a tracking comment**. A human addresses the bot and gets nothing, on a green check.

The four `contains()` clauses (`claude.yml:91,95,99,101`), the `trigger_phrase` input,
`bonsai-status-sync.yml:134`'s grep, and **the out-of-repo cron orchestrator that writes `@claude` into issue
bodies** must all move in one commit.

**Therefore: identity and phrase are separable, and should be separate waves.** Swapping the token is a
zero-UX-change move. Flipping the phrase is a coordinated one-literal cutover including a repo this scope
does not cover. Ship identity first.

### 4. `AGENTS_GH_PAT`'s live scope is unknown, and the docs contradict each other

`claude.yml:180` uses `AGENTS_GH_PAT` to `gh repo clone` the **private** `driver-agents` repo — which requires
`Contents: read`. But `templates/github/README.md:82-86` says the token has "no Contents", and
`pr-first-review.yml:22-24` says "Contents: READ". Three descriptions, two mutually inconsistent, none
verified.

A cutover that recreates the token "to the documented shape" will 403 the Shopify provisioning step on every
store repo — **and that step degrades silently** (`::warning::` + `exit 0`), so it surfaces as "the implementer
mysteriously didn't touch the store."

Also undocumented: the reviewer token needs **`Actions: read`** for `dependabot-report.yml:85`'s artifact
download, or that rail 403s.

**Fix:** dump the live scope *first* (read the `x-accepted-github-permissions` response header), write it
down, then design the split. Move the `driver-agents` clone onto the implementer token so the reviewer token
can be `Contents: none` for real.

### 5. Token revocation disappears

Supplying `github_token` also removes the per-run App-token revocation. An ephemeral, auto-revoked credential
becomes a long-lived PAT stored fleet-wide on an account that holds write across 21 targets. PAT expiry
becomes a single point of failure with no alerting.

---

## Loop containment — the centrepiece

**Today's safety is 100% accidental identity asymmetry, and this was verified empirically, not assumed.**
Querying real comments: `claude[bot]` → `author_association: NONE`, `type: Bot`; `driver-digital-agents` →
`author_association: MEMBER`, `type: User`.

Two independent brakes collapse on unification:

1. **`claude.yml`'s actor gate.** Today `claude[bot]`'s own comments fail *both* branches (NONE is not
   OWNER/MEMBER/COLLABORATOR, and the login is not `driver-digital-agents`). After unification the agent's own
   comments pass on **`MEMBER` alone** — so deleting the login+id whitelist would not help.
2. **The action's own `checkHumanActor`** throws `Workflow initiated by non-human actor` for `type !== "User"`.
   A machine *User* passes silently. `checkWritePermissions` passes too. Both action-level brakes vanish.

**What still terminates — and this is load-bearing and documented nowhere:** the agent's final response is an
`updateComment` (`issue_comment: edited`), and every `on:` block subscribes to **`[created]` only**. That
single fact is what stops the human-reply path. **Adding `edited` to any `types:` list is an instant infinite
loop.** Write that invariant into the file.

Two near-misses worth knowing: the tracking comment *is* a `createComment` and after unification it cascades —
it survives only because its body contains no mention. And `comment-logic.ts:127` writes the header
`**Claude finished @${username}'s task**`, which on a self-triggered run embeds the account's own mention into
an agent-authored comment.

**The unbounded path (the real hazard):** Claude holds `Bash` with `gh` authenticated as the token identity.
Tag mode's system prompt says "Never create new comments" — that is **prose, not a gate**. One `gh pr comment`
echoing a human's request (which contains the trigger phrase) re-enters the gate under a MEMBER association.

### Minimum containment set

1. **Self-authored guard** — every actor-gate branch gains `github.event.*.user.id != 261291955`. Cost: the
   agent can no longer hand off to itself across events. Accept that; it is the point.
2. **Keep `types: [created]` everywhere**, with a comment stating why. Never add `edited`.
3. **Sentinel matching becomes `startsWith`, not `contains`** (`ticketed-review.yml:38-40`, and the jq at
   `:137`) so a quote-reply that copies a hidden marker cannot inflate the round count.
4. **Round/finding counters must stop keying on `user.login`**, which no longer separates reviewer from
   implementer. Use a newest-comment-id watermark instead of the `SINCE` timestamp (`:153-158`).
5. **Global kill switch** — `vars.AGENTS_ENABLED != 'false'` as the leading conjunct of the gate, settable
   org-wide to stop the fleet in one action.
6. **Per-thread run budget** — a hard cap on agent runs per issue/PR, independent of the ticketed round cap.

---

## Token design

Two fine-grained PATs on the **same account** (confirmed supported; both render as `driver-digital-agents`).
This bounds the **tokens**, not the account — worth stating plainly, since the account becomes a code-write
principal across 21 repos either way.

| | Implementer PAT | Reviewer PAT |
|---|---|---|
| Contents | **write** on the 21 targets, **read** on `driver-agents` | **none** |
| Issues | read/write | read/write |
| Pull requests | read/write | read/write |
| Metadata | read | read |
| Actions | — | **read** (artifact download) |
| Workflows | **no** — see below | no |

**Do not grant `Workflows: write`.** A fine-grained PAT with it can modify `.github/workflows/`, which the App
token structurally could not. That is a privilege *expansion* hiding inside a migration framed as
consolidation.

**Unverified:** `gh issue develop` runs the GraphQL `createLinkedBranch` mutation, whose fine-grained
permission requirement GitHub does not publish. This must be proven in the pilot, not assumed.

---

## Sequencing

**Wave 1 — identity only.** Swap the token, drop `id-token`, set `bot_id`/`bot_name`, fix the rail gates,
apply the containment set. **Zero UX change** — humans still type `@claude`.

**Wave 2 — trigger phrase.** Flip to `@driver-digital-agents` in one coordinated commit spanning this repo,
the fleet, and the cron orchestrator in `driver-bonsai-mcp`.

**Then the reusable conversion**, which is now materially cheaper: Phase 0 (the OIDC spike) **ceases to
exist**, and the stub no longer needs `id-token: write`.

| Phase | Work | Est. |
|---|---|---|
| 0 | Dump live `AGENTS_GH_PAT` scope; mint + test the two PATs | 2h |
| 1 | Rate-limit measurement spike (`GET /rate_limit` instrumentation) | 2h |
| 2 | `claude.yml` identity swap + containment set | 4–6h |
| 3 | Rail gate rework (3 sites + counters + sentinel matching) | 3–4h |
| 4 | Move reads onto `github.token`; add write retry/backoff | 3h |
| 5 | Pilot (two legs, assertions below) | 4h |
| 6 | Fleet wave, 21 targets | 4h |
| 7 | Wave 2: trigger phrase, incl. the orchestrator | 3h |
| | **Total** | **25–28h** |

---

## Pilot

**Leg 1: `vite-plugin-shopify-clean`** — public, single branch, 7 prior `claude[bot]` PRs so the path is
proven there, no client and no store credentials.
**Leg 2: `foundrae-blackridge` (`staging`)** — private, the designated test bed; the only leg that exercises
the private-repo fetch path.

Do **not** pilot in `plugins`, `client-workspaces` or `studio-sulzer` — zero `claude[bot]` PRs ever, so a
failure is unattributable. `claude.yml` is still a full per-repo file, so one repo can be cut over
independently without touching the other 20.

**Assertions, each with its false-pass named:**

1. **Authorship** — the PR's `user.login` is `driver-digital-agents`. *False pass:* a prefill PR link, or
   `gh pr view` reporting `app/claude`. Read the webhook.
2. **Commit attribution** — commits are authored by `driver-digital-agents`, not `github-actions[bot]`.
   *False pass:* checking the PR author instead of the commits.
3. **Cascade** — a `bonsai-status-sync` run exists triggered by `pull_request`/`opened`, and the Bonsai task
   reads Internal Review. *False pass:* the task already being in that state.
4. **Ticketed rail fires** — exactly one `ticketed-review` run for the PR, and it actually reviews.
   *False pass:* a green skip; assert a check run exists.
5. **Tag mode intact** — a human `@` gets a visible tracking comment *and* a final reply. *False pass:*
   a green run with no comment — the #148 signature.
6. **No self-trigger** — after the agent replies, assert zero further `claude.yml` runs on that thread.
7. **`gh issue develop` works** on the implementer PAT's fine-grained scope.
8. **Rate-limit headroom** — `x-ratelimit-used` recorded at job end, extrapolated to wave size.

**Rollback:** `claude.yml` triggers are default-branch-only, so a revert has no effect until merged, and every
consuming repo requires a human approver. Pre-stage the pre-cutover file on a
`rollback/claude-yml-pre-identity` branch in each target so the revert is a one-click PR. Name the
out-of-hours approver per repo. The old file is self-contained, so revert is complete once merged.

---

## Open decisions

1. **Does the rate-limit reduction change your mind?** ~58–61% aggregate, and the 500/hr content bucket
   halving. Mitigable, but it is a real regression and the strongest argument against.
2. **Should the Claude App be uninstalled** after cutover, or left installed and unused? Nothing else consumes
   it. Recommend leaving it until Wave 2 completes, then removing as cleanup.
3. **Wave 2 at all?** `@claude` is muscle memory and works fine. The colleague goal argues for
   `@driver-digital-agents`; the risk is a coordinated cutover across three repos including the orchestrator.
4. **Per-thread run budget:** what number? Suggest 10 agent runs per issue/PR before the circuit opens.

---

## Provenance

Researched 2026-07-31 by five parallel agents across: action behaviour with a PAT, token design and rate
limits, loop containment, rail gates, and migration. Ten hard-blocker claims were each put to an adversarial
challenge agent instructed to refute them; **all ten were refuted** — nothing structurally blocks this, but
five findings are silent-failure class and are treated as requirements above. Sourced to official GitHub docs,
`anthropics/claude-code-action` at pinned SHA `be7b93b1907a4abad570368f3c74b6fe3807510b`, live `gh api` queries
against the DriverDigital org, and this repo's own files.
