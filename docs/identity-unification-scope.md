# Scope: drop the Claude App, unify the GitHub surface on `driver-digital-agents`

**Status:** scoped, not started. **Written:** 2026-07-31 against `main` @ `9b70acf` (tag `v1.6.0`).
**Refreshed:** 2026-08-02 (v1.9.0, then v1.11.0); **citations re-verified 2026-08-22 at `v1.13.0`, where
`templates/github/claude.yml` is 500 lines.** They are path-qualified — several filenames exist in both
`templates/github/` and `.github/workflows/` with different content and lengths. **Six corrections change
what someone would build** — listed in *Provenance*, marked **Correction** where they appear. The headline
rate-limit finding **survives re-checking**.
**Decision made:** the GitHub agent stays in GitHub Actions. Only the identity underneath it changes.
Nothing moves to a server. A Slack agent is a separate entity, explicitly out of scope.

> ## ⏸ DEFERRED — Maria, 2026-08-02
>
> **Not scheduled.** We are not ready to drop the Claude App and run the whole GitHub surface as
> `driver-digital-agents`. This is a future project, kept scoped so it can be picked up without
> re-researching.
>
> Consequence for the sibling project: the OIDC spike in
> [`reusable-conversion-scope.md`](reusable-conversion-scope.md) does **not** get retired, so the
> `claude.yml` half of that conversion stays gated — and has itself been tabled for now. The
> `bonsai-status-sync` half proceeded independently (and was retired at v1.13.0).
>
> **2026-08-22 — cheaper now; the costs still stand.** Retiring the review rails at v1.12.0/v1.13.0 took
> Phase 3 and silent-failure risk 1 with it — the two things that made this project expensive and risky —
> bringing the total from 26–30h to **21–24h**. Nothing else moved: the PR author still flips from
> `claude[bot]` to `driver-digital-agents`, and the aggregate API ceiling still drops 58–61% with the
> content bucket halving to a shared 500/hr and 80/min. **Status unchanged: DEFERRED.**

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

*Re-verified 2026-08-02 against live org data and current GitHub docs. The headline holds: corrected range is
**58.0–61.2%**. Three inputs were wrong or incomplete; none of them changes the conclusion.*

DriverDigital is on the **Team** plan (not Enterprise Cloud; verified via `gh api /orgs/DriverDigital` →
`plan.name = "team"`). This is load-bearing — Enterprise Cloud would give a flat 15,000/hr installation limit
*and* 15,000/hr per repo for `GITHUB_TOKEN`, which would change every number here.

The Claude App is installed org-wide (`repository_selection: "all"`) across **58 repos**, giving its
installation token roughly **6,900–7,900 req/hr**. The full documented formula:

> 5,000 base. Installations with **more than 20 repositories** receive another 50 req/hr **per repository**.
> Installations on an organization with **more than 20 users** receive another 50 req/hr **per user**.
> Capped at 12,500.

**It scales on users *and* repositories** — the original draft cited only the repository term. That omission is
harmless here: DriverDigital has **7 members** (11 seats counting 4 outside collaborators), far below the
>20-user threshold, so the user term contributes exactly **0**. Worth stating explicitly, because the user term
can only push the ceiling *up*, so including it can only ever *strengthen* this argument. The org would need to
roughly triple headcount before it engaged.

The stated range spans the two readings of "another 50 per repository": `5,000 + 50×(58−20) = 6,900` and
`5,000 + 50×58 = 7,900`. GitHub's wording is genuinely ambiguous; the cap is not reached either way.
*Unverified:* whether the 8 archived repos count. If they do not, the range is 6,500–7,500 — the conclusion
survives that too.

A user PAT is a **flat 5,000/hr** with no scaling — and critically it is **per-account, not per-token**
("combined with any requests that another GitHub App or OAuth App makes on that user's behalf and any requests
that the user makes with a personal access token"), so the proposed two-PAT split does *not* buy two buckets.

**Corrected arithmetic.** Before: App installation token + `driver-digital-agents` PAT. After: PAT only.

```
Reading A:  6,900 + 5,000 = 11,900  →  5,000     drop 6,900/11,900 = 58.0%
Reading B:  7,900 + 5,000 = 12,900  →  5,000     drop 7,900/12,900 = 61.2%
```

Worse is the secondary limit: **500 content-generating requests per hour — and no more than 80 per minute**.
The per-minute ceiling was missing from the original draft and is arguably the more dangerous of the two for
this workload: a 141-run burst in ~35 minutes is exactly the shape that trips a per-minute limit long before
the hourly one. GitHub also notes "some endpoints have lower content creation limits" without publishing the
values. Content-creation limits explicitly "include actions taken on the GitHub web interface."

Today `claude[bot]` and `driver-digital-agents` have independent 500/hr buckets. After unification they share
one. **Caveat added on refresh:** GitHub does *not* publish the keying granularity of secondary limits. That
they are keyed per-account is a reasonable inference from the web-UI inclusion, but it is inference, not
citation — and the same page warns secondary limits "are subject to change without notice" and may trigger
"for undisclosed reasons." A go/no-go resting on an undocumented keying rule should say so out loud.

Order of magnitude: a full ticketed cycle is roughly 30–60 content operations (tracking comment, branch
create, PR create, sentinel, plus 5–15 inline findings per review pass across up to 3 passes). **If 40 runs
complete a full cycle within an hour, that is 1,200–2,400 content ops against a 500/hr ceiling on one
account.** The 141-run wave on 2026-07-31 is not a hypothetical.

**Mitigations, in order of value:**

1. **Move reads that do not need the machine-user identity onto `github.token`** — a separate
   **1,000/hr *per repository*** bucket. **Dormant since v1.12.0:** every read site was in the two review
   reusables, so this applies only if those rails are re-activated, and its hours are out of the table
   below. Two cautions for whoever revives it: the 1,000 is **per repo**, not a pool a single busy repo can
   draw on — which is exactly the wave shape that motivates this section; and any site that *writes*, or
   that calls `gh api user --jq .login` to resolve **the bot's own identity**, must be excluded by name —
   under `github.token` that call returns `github-actions[bot]`, the count matches nothing, and a false
   **"All clear ✅"** gets posted.

2. **Measure before committing — by counting content operations client-side, not by polling `/rate_limit`.**
   Since no server-side counter for the secondary limit exists:
   1. **Count content-generating calls at the call sites** — comment / issue / PR / review / commit
      creations. Self-instrumentation is the only way to know your rate against 500/hr and 80/min.
   2. **Track the per-minute rate, not just the hourly total** — 80/min is the likelier binding constraint
      for a burst wave.
   3. Capture every `403`/`429` **response body** — it names "secondary rate limit" in the message, which is
      the only way to distinguish it from a primary-limit `403`.
   4. On those responses record the **`retry-after`** header plus `x-ratelimit-remaining` /
      `x-ratelimit-reset`; GitHub prescribes different backoff depending on which is present.

   > **Correction (2026-08-02).** The original plan — poll `GET /rate_limit` at job start and end, echo
   > `x-ratelimit-used`, "that endpoint does not count against the limit" — **could not have measured the
   > constraint this section is about.** `/rate_limit` and the `x-ratelimit-*` headers instrument the
   > **primary** REST limit only; GitHub states flatly *"There is not a way to check the status of your
   > secondary rate limit."* It would have reported healthy primary headroom and been read as "no problem
   > here." Worse, the endpoint *"can count against your secondary rate limit"* — the instrument consumes the
   > budget it cannot read.

3. Add 403/429 retry-with-backoff on every `gh` **write**. (The sites below are in the retired review
   rails — same dormancy as mitigation 1; `claude.yml`'s own `gh` writes still want the retry.) Today `ghj()`
   (`.github/workflows/ticketed-review.yml:72-79`) retries reads only, and `gh pr comment` at `:260`/`:285`
   has no retry at all — a secondary-limit 403 there stalls the loop silently.

   > **Correction (2026-08-02).** `ghj()` is defined *inside the "Resolve" step's own `run:` block*
   > (`:66-120`). The decide step (`:241-287`) is a **separate shell**, so the function is not in scope there.
   > "Wrap `:260`/`:285` in the existing helper" is not a move — it is a re-implementation, or a hoist of
   > `ghj()` into a shared script both steps source. Budget it as such.

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
  actor is a `User`. Remove `.github/workflows/ticketed-review.yml:199` as cleanup, not as a fix. *(Confirmed
  on refresh: `:199` is `allowed_bots: "claude[bot]"`. The 49-line caller stub has no line 199 — this is the
  reusable.)*
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

## The silent-failure risks

Every one of these fails **green**. That is the house failure mode (foundrae #148) and the reason this scope
exists.

### 1. Ticketed PRs would be reviewed by nobody

**Retired.** This hung on `templates/github/ticketed-review.yml:38` gating round 1 on
`pull_request.user.login == 'claude[bot]'`; that stub left the kit and every fleet repo at v1.12.0, and
Macroscope reviews PRs now. It returns only if the rails do. (Risks 2–5 keep their numbers.)

*Id census, re-counted 2026-08-22:* `261291955` (`driver-digital-agents`) has **7** occurrences across two
files — `templates/github/claude.yml` (6) and `README.md` (1). `claude[bot]`'s id `209825114` appears in no
workflow file. Wherever both logins must be accepted, pair **each login with its own id**, OR'd as complete
units: a single shared id checked against two logins evaluates false for every real event, and fails as a
**skipped job**, not a red run.

### 2. Commit attribution stays wrong unless set explicitly

`bot_id`/`bot_name` are **not** derived from the token, and their default is `github-actions[bot]` — not even
`claude[bot]`. Left alone, every implementer commit is misattributed. Set
`bot_name: driver-digital-agents`, `bot_id: "261291955"`.

### 3. Trigger-phrase mismatch is the #148 signature exactly

If the workflow gate accepts `@claude` while `trigger_phrase` is `@driver-digital-agents`, the job starts, tag
mode is selected, `checkContainsTrigger` returns false, and `run.ts:212` logs "No trigger found" and returns
**success without posting a tracking comment**. A human addresses the bot and gets nothing, on a green check.

Three things must move in one commit: the four `contains()` clauses
(`templates/github/claude.yml:94,98,102,104`), a `trigger_phrase` input on the action, and **the dispatcher in
`driver-bonsai-mcp`, which writes `@claude` into every issue body it opens**.

Note `trigger_phrase` **does not exist in this repo today** (`git grep` → zero hits) — the action runs on its
default phrase. So it must be *added* in the same commit, not edited. That is a small but real difference: the
first time it appears is the first time it can disagree with the workflow gate, which is the #148 signature.

**Therefore: identity and phrase are separable, and should be separate waves.** Swapping the token is a
zero-UX-change move. Flipping the phrase is a coordinated one-literal cutover including a repo this scope
does not cover. Ship identity first.

### 4. `AGENTS_GH_PAT`'s live scope is unknown, and the docs contradict each other

`templates/github/claude.yml:180` binds `AGENTS_GH_PAT` as the `GH_TOKEN` that `gh repo clone`s the **private**
`driver-agents` repo at `:218` — which requires `Contents: read`. There are **two** written descriptions of
that token and they do not agree: `.github/workflows/pr-first-review.yml:31-32` says "Issues + Pull-requests
R/W, Contents:READ, no Admin", while `templates/github/README.md:64-66` describes `AGENTS_GH_PAT` and lists
**no permissions at all**. Neither is verified against the live token, so a cutover that recreates it "to the
documented shape" has two shapes to choose from, one omitting `Contents` entirely.

A cutover that recreates the token "to the documented shape" will 403 the Shopify provisioning step on every
store repo — **and that step degrades silently** (`::warning::` + `exit 0`), so it surfaces as "the implementer
mysteriously didn't touch the store."

Also undocumented: the reviewer token needs **`Actions: read`** for
`.github/workflows/dependabot-report.yml:85`'s artifact download (`github-token:` on the
`actions/download-artifact` step), or that rail 403s.

**Fix:** dump the live scope *first* (read the `x-accepted-github-permissions` response header), write it
down, then design the split. Move the `driver-agents` clone onto the implementer token so the reviewer token
can be `Contents: none` for real.

### 5. Token revocation disappears

Supplying `github_token` also removes the per-run App-token revocation. An ephemeral, auto-revoked credential
becomes a long-lived PAT stored fleet-wide on an account that holds write across every target
([`fleet-operations.md`](fleet-operations.md#the-fleet)). PAT expiry
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
`updateComment`, which fires `issue_comment: edited` (and, on the inline-review rail,
`pull_request_review_comment: edited`). **Neither of those two events subscribes to `edited`** —
`templates/github/claude.yml:49` and `:60` are `[created]` only. That is what stops the human-reply path.
**Adding `edited` to either `types:` list re-opens the loop.** Write that invariant into the file.

The full block (`templates/github/claude.yml:47-60`) — only the two `[created]` rows are loop-relevant:

| Event | Line | `types:` |
|---|---|---|
| `issue_comment` | `:49` | `[created]` |
| `issues` | `:54` | `[opened]` |
| `pull_request_review` | `:57` | `[submitted]` |
| `pull_request_review_comment` | `:60` | `[created]` |

A self-retrigger additionally requires the actor gate to pass on the bot's own edited comment. Today it would
not (`claude[bot]` is `author_association: NONE` and not the whitelisted login). **After unification it
would** — `driver-digital-agents` is explicitly whitelisted at `:100-101`. The invariant becomes load-bearing
precisely when this project ships.

> **Correction (2026-08-02).** The original draft said "**every** `on:` block subscribes to `[created]` only"
> and that adding `edited` to **any** `types:` list is an "instant infinite loop." The first is impossible as
> stated — GitHub's `issues` event has no `created` activity type — and scoping the rule to all four events
> makes it read as superstition and get ignored. Scope it to the two that can actually carry a comment edit.

Two near-misses worth knowing: the tracking comment *is* a `createComment` and after unification it cascades —
it survives only because its body contains no mention. And `comment-logic.ts:127` writes the header
`**Claude finished @${username}'s task**`, which on a self-triggered run embeds the account's own mention into
an agent-authored comment.

**The unbounded path (the real hazard):** Claude holds `Bash` with `gh` authenticated as the token identity.
Tag mode's system prompt says "Never create new comments" — that is **prose, not a gate**. One `gh pr comment`
echoing a human's request (which contains the trigger phrase) re-enters the gate under a MEMBER association.

### Minimum containment set

1. **Self-authored guard** — every actor-gate branch gains a self-id exclusion, written **per-event**. Cost:
   the agent can no longer hand off to itself across events. Accept that; it is the point.

   | `github.event_name` | id field to use | login/id clause exists today? |
   |---|---|---|
   | `issues` | `github.event.issue.user.id` | yes — `:96-97` |
   | `issue_comment` | `github.event.comment.user.id` | yes — `:100-101` |
   | `pull_request_review` | `github.event.review.user.id` | **no** — `:102-103` gates on `author_association` only |
   | `pull_request_review_comment` | `github.event.comment.user.id` | **no** — `:104-105`, same |

   The right-hand column is the hidden work: on the two review events there is **no existing clause to
   extend**, so those branches must grow a login/id check from nothing.

   > **Correction (2026-08-02) — never write this with a wildcard.** The original draft gave it as
   > `github.event.*.user.id != 261291955`. That is **not** a syntax error — `*` is GitHub's documented object
   > filter — which makes it far more dangerous: it returns an **array**, an array coerced to a number is
   > `NaN`, and `NaN != 261291955` is **`true` unconditionally**. The guard would never fire on any event, and
   > nothing would surface it: no lint error, no startup failure, no red run. It fails open, silently, which
   > is the exact failure class this section exists to prevent.

2. **Keep `types: [created]` on `issue_comment` and `pull_request_review_comment`**, with a comment stating
   why. Never add `edited` to either. (The other two events carry different
   types by design, and changing *those* is a different question.)
3. **Sentinel matching becomes `startsWith`, not `contains`** — **dormant**: the matching lived in the
   retired `ticketed-review` stub. `claude.yml:484` still *posts* the sentinel, so keep it distinct from the
   round marker `<!-- ticketed-review-round -->`; collapsing the two invites collapsing them in code, which
   that design forbids.
4. **Round/finding counters must stop keying on `user.login`** — **dormant** for the same reason; the
   counters are in the retired `ticketed-review` reusable. If the rails come back: the
   `select(.user.login=="driver-digital-agents")` hardcode has **two** sites, `:137` and `:252`, and
   changing only the first silently forces a handoff on every run.
5. **Global kill switch** — `vars.AGENTS_ENABLED != 'false'` as the leading conjunct of the gate, settable
   org-wide to stop the fleet in one action.
6. **Per-thread run budget** — a hard cap on agent runs per issue/PR, independent of the ticketed round cap.

---

## Token design

Two fine-grained PATs on the **same account** (confirmed supported; both render as `driver-digital-agents`).
This bounds the **tokens**, not the account — worth stating plainly, since the account becomes a code-write
principal across every target either way. *(Size Phase 6 off the fleet table in
[`fleet-operations.md`](fleet-operations.md#the-fleet), which is the single home for the counts and says
which question each one answers — repo@branch pairs and distinct repos differ, Palmers alone being 8
branches.)*

| | Implementer PAT | Reviewer PAT |
|---|---|---|
| Contents | **write** on the targets, **read** on `driver-agents` | **none** |
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

**Wave 1 — identity only.** Swap the token, drop `id-token`, set `bot_id`/`bot_name`, apply the containment
set. **Zero UX change** — humans still type `@claude`.

**Wave 2 — trigger phrase.** Flip to `@driver-digital-agents` in one coordinated commit spanning this repo,
the fleet, and the dispatcher in `driver-bonsai-mcp`.

**Then the reusable conversion**, which is now materially cheaper: Phase 0 (the OIDC spike) **ceases to
exist**, and the stub no longer needs `id-token: write`.

| Phase | Work | Est. |
|---|---|---|
| 0 | Dump live `AGENTS_GH_PAT` scope; mint + test the two PATs | 2h |
| 1 | Rate-limit measurement spike (**client-side content-op counting** — not `/rate_limit`; see mitigation 2) | 2h |
| 2 | `claude.yml` identity swap + containment set | 4–6h |
| 4 | Write retry/backoff on `claude.yml`'s own `gh` writes | 2h |
| 5 | Pilot (two legs, 10 assertions below) | 4–5h |
| 6 | Fleet wave ([`fleet-operations.md`](fleet-operations.md#the-fleet) for the target set) | 4h |
| 7 | Wave 2: trigger phrase, incl. the dispatcher | 3h |
| | **Total** | **21–24h** |

*Down from 26–30h on 2026-08-22: Phase 3 (rail-gate rework, 3–4h) and the `github.token` half of Phase 4
(2h) came out with the review rails. Add them back if the rails are re-activated.*

**This total is not comparable to the one in
[`reusable-conversion-scope.md`](reusable-conversion-scope.md)** (20–27h tabled subtotal) — different
project. Doing this one first retires that one's Phase 0, bringing it to 17–23h.

---

## Pilot

**Leg 1: `vite-plugin-shopify-clean`** — public, single branch, 7 prior `claude[bot]` PRs so the path is
proven there, no client and no store credentials.
**Leg 2: `foundrae-blackridge` (`staging`)** — private, the designated test bed; the only leg that exercises
the private-repo fetch path.

Do **not** pilot in `plugins`, `client-workspaces` or `studio-sulzer` — zero `claude[bot]` PRs ever, so a
failure is unattributable. `claude.yml` is still a full per-repo file, so one repo can be cut over
independently without touching the rest of the fleet.

**Assertions, each with its false-pass named:**

1. **Authorship** — the PR's `user.login` is `driver-digital-agents`. *False pass:* a prefill PR link, or
   `gh pr view` reporting `app/claude`. Read the webhook.
2. **Commit attribution** — commits are authored by `driver-digital-agents`, not `github-actions[bot]`.
   *False pass:* checking the PR author instead of the commits.
3. **Cascade** — the dispatcher's poll moves the Bonsai task to Internal Review. *False pass:* the task
   already being in that state.
4. ~~**Ticketed rail fires.**~~ Retired with the review rails; restore this assertion only if they are.
5. **Tag mode intact** — a human `@` gets a visible tracking comment *and* a final reply. *False pass:*
   a green run with no comment — the #148 signature.
6. **No self-trigger** — after the agent replies, assert zero further `claude.yml` runs on that thread.
7. **`gh issue develop` works** on the implementer PAT's fine-grained scope.
8. **Rate-limit headroom** — `x-ratelimit-used` recorded at job end for the **primary** limit, *plus* a
   client-side count of content-generating calls and any `403`/`429` bodies naming the secondary limit.
   Extrapolate both to wave size. *False pass:* reporting primary headroom only — see mitigation 2, the
   secondary limit has no status endpoint and is the one expected to bind.
9. **Private clone succeeds** — `templates/github/claude.yml:218` actually clones `driver-agents` at the
   pinned revision on the implementer PAT. *False pass:* the step's own degrade path — `::warning::` at
   `:230` then `exit 0` at `:232`, so the job stays green. Assert on the **absence of that warning**, not on
   job status. This is the assertion that covers risk 4 (`Contents: read` on a private repo), and leg 2 is
   the only leg that exercises it.
10. **Store provisioning succeeds** — on a store repo, `SHOPIFY_STORE_NAME` is non-empty, the env file is
    written (`:238`), and the audit artifact uploads under a name containing the store handle (`:498`).
    *False pass:* the same silent self-skip — the missing-secret early-exit at `:200-202` is deliberate
    degrade-quietly behaviour, and an artifact named `shopify-audit--<run_id>-…` uploads perfectly happily.

*(Assertions 9 and 10 were added on the 2026-08-02 refresh. Both failure paths were already identified in this
document, but the original list never required either operation to succeed — so a pilot could have passed every
stated check while the implementer quietly lost store access on every store repo.)*

**Rollback:** `claude.yml` triggers are default-branch-only, so a revert has no effect until merged, and every
consuming repo requires a human approver. Pre-stage the pre-cutover file on a
`rollback/claude-yml-pre-identity` branch in each target so the revert is a one-click PR. Name the
out-of-hours approver per repo. The old file is self-contained, so revert is complete once merged.

---

## Open decisions

1. **Does the rate-limit reduction change your mind?** **58.0–61.2%** aggregate (re-verified 2026-08-02
   against live org data — 58 repos, Team plan), plus the content bucket halving: **500/hr and 80/min**, the
   per-minute ceiling being the likelier one to bind on a wave. Mitigable, but it is a real regression and
   the strongest argument against. Two honesty caveats now stated in the section itself: the per-account
   keying of secondary limits is **inference, not documented**, and the `github.token` mitigation is
   per-repository capacity rather than a shared pool.
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

**Re-verified 2026-08-22 at `v1.13.0`.** Citations moved with that release's rewrite of `claude.yml` (500
lines); the workstreams aimed at the retired review rails — Phase 3, silent-failure risk 1, mitigation 1 and
containment items 3–4 — were cut back to one line each rather than repaired, and their hours removed from the
total. The rate-limit finding, the loop-containment invariant and the token design are unchanged.

**Refreshed 2026-08-02** against `main` @ `a54c91e` (v1.9.0) and re-verified against the v1.11.0 release
branch, with the rate-limit section re-derived from live
org data and current GitHub documentation. **The recommendation is unchanged and the headline finding
survives** (58.0–61.2%). Six corrections changed what someone would build — the self-authored guard, the
dual-accept id pairing, the measurement instrument, the loop invariant's scope, the second round-counter site,
and the two missing pilot assertions. Each is marked **Correction** where it appears.

Three originate in the CodeRabbit review of PR #21 and were confirmed independently before adoption; three
came out of the refresh. One reviewer rationale was itself corrected in adopting it: the wildcard guard is not
invalid syntax, which makes it more dangerous rather than less. The **external** citations into
`anthropics/claude-code-action` were *not* re-verified — they remain as originally researched at the pinned
SHA.
