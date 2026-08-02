# Scope: convert `claude.yml` + `bonsai-status-sync.yml` into reusable workflows

**Status:** `bonsai-status-sync` half IN PROGRESS (Phase 1 done); `claude.yml` half TABLED. **Written:** 2026-07-31 against `main` @ `9b70acf` (tag `v1.6.0` = `0a3934f`).
**Refreshed:** 2026-08-02 against `main` @ `a54c91e` (tag `v1.9.0`). Three releases landed underneath the
original draft — v1.7.0 (Slack alerting), v1.8.0 (audit context + artifact leg), v1.9.0 (store-secret rename).
Every `file:line` citation below is re-verified against `a54c91e`; every number is recomputed. Citations are
now **path-qualified**, because several filenames exist in both `templates/github/` (short caller stubs) and
`.github/workflows/` (long reusables) with entirely different content — the original draft cited both under
one bare name.

The README has flagged this as "future work" since the repo split. This document is the scope to execute it.

> ## Decision — Maria, 2026-08-02: split the project, ship the `bonsai-status-sync` half
>
> **APPROVED and IN PROGRESS — `bonsai-status-sync.yml` (Phases 1–3).** The copy-per-repo cost is real
> and this half was never gated on anything. Phase 1 landed 2026-08-02: the reusable is
> `.github/workflows/bonsai-status-sync.yml`, the 190-line per-repo copy is now a 51-line caller stub.
>
> **TABLED — `claude.yml` (Phase 0 and Phases 4–8).** Whether Claude App token minting survives inside a
> cross-repo reusable is a question for another day. `claude.yml` stays a full per-repo file, and remains
> the kit's one drift surface. Do not start Phase 4 without re-opening this decision.
>
> **DEFERRED — [`identity-unification-scope.md`](identity-unification-scope.md).** Not ready to drop the
> Claude App, so the Phase 0 spike is *not* retired by that project shipping first.
>
> Three open decisions were closed by this decision or by direct verification — see *Open decisions* below.

---

## Why

*As of the Phase 1 conversion (2026-08-02) this argument is half-resolved: `bonsai-status-sync.yml` is now a
51-line stub calling a central reusable. **`claude.yml`'s 460 lines remain copied** — still the single largest
thing in the kit and its only remaining drift surface. The original framing follows.*

Of the 916-line kit, **650 lines (71%) were the two files copied verbatim rather than called** —
`claude.yml` (460) and `bonsai-status-sync.yml` (190). The five caller stubs totalled 154 lines and are
mechanical.

*At v1.6.0 this read 594 of 837 — the same 71%. The flat ratio hides the trend: over three releases the
copied-per-repo surface grew **56 lines** and the called surface grew by **zero**, and every one of those 56
lines is in `claude.yml` (`bonsai-status-sync.yml` is byte-identical to v1.6.0). There is now also a **third**
copied-and-hand-edited file — `shopify-tool-smoke.yml`, 89 → 112 lines — which is why open decision 1 got more
expensive rather than less.*

Every drift incident traces to that split. Avara shipped the prompt-hijack bug because `claude.yml` is
copied, so a subset of upstream changes could be hand-carried into it. The store handle needs preserving on
re-copy because it is a hand-edited line in a copied file. `DRIVER_AGENTS_REF` is duplicated because it lives
in copied files.

**Conversion does not eliminate waves** — SHA-pinned stubs still need a pin bump per change. It changes what a
wave *is*: from re-copying 650 lines into every target while hand-preserving per-repo edits, to changing one
SHA string.

**Implementation drift becomes structurally impossible** — there is no downstream logic left to edit. Be
precise about the scope of that claim: caller *configuration* drift does not disappear. `SHOPIFY_STORE_NAME`,
`permissions:`, `concurrency:`, and the secret mapping still live in each repo's stub and can still diverge,
and `DRIVER_AGENTS_REF` stays hand-edited fleet-wide for as long as `shopify-tool-smoke.yml` remains a copied
file (open decision 1). What conversion removes is the 650 lines of *logic* that a wave could hand-carry a
subset of — which is the specific failure that produced the Avara incident.

Secondary win: `actions/checkout` (`templates/github/claude.yml:130`), `claude-code-action` (`:304`) and
`actions/upload-artifact` (`:456`, added by v1.8.0) move out of `templates/` and into `.github/workflows/`,
which `.github/dependabot.yml` (`directory: "/"`) actually scans — converting **three** documented manual pins
into bot-managed ones.

---

## Verdict: viable, gated on one spike

Six claims were raised as hard blockers during research. **All six were refuted under adversarial challenge.**
Nothing structurally prevents this. But one undocumented behaviour decides whether `claude.yml` ships in this
form at all, and it must be settled before **any work on `claude.yml`**.

**It does not gate the whole project.** `bonsai-status-sync.yml` has no OIDC path and no App token, so Phases
1–3 + 5 (**9–10h**) are unaffected by the spike's outcome *and* unaffected by the identity decision. That is
exactly why they were split off and approved on 2026-08-02 while this spike was tabled. Everything below about
Phase 0 concerns `claude.yml` only.

### THE GO/NO-GO — Phase 0 spike

> **Skip this entire section if [`identity-unification-scope.md`](identity-unification-scope.md) ships first.**
> Without the Claude App there is no OIDC exchange to validate, and this spike has nothing to test.

`claude-code-action` mints the Claude App installation token by POSTing its OIDC token to Anthropic's
`github-app-token-exchange`. Since 2025-08-12 that endpoint validates that **the workflow file is
content-identical to the version on the repository's default branch** (error:
`workflow_not_found_on_default_branch`).

**The unknown:** does it validate `workflow_ref` (the consumer's caller stub) or *also* `job_workflow_ref`
(our SHA-pinned reusable)?

- If only the caller stub → fine. The stub always runs from the default branch, so it validates trivially.
- If also the reusable → **every SHA pin becomes invalid the moment `workflows/main` advances past the tag**,
  and the immutable-SHA policy (decided 2026-06-17) would have to be abandoned for `@main` refs. Unacceptable
  for a workflow that mints `contents: write`.

Evidence it does *not* validate the reusable (strong but circumstantial): on
[anthropics/claude-code-action#443](https://github.com/anthropics/claude-code-action/issues/443), Anthropic's
`ashwin-ant` shipped a cross-repo fix on 2025-08-19; `SHxKM` (2026-01-19) ran precisely our shape — consumer
stub → cross-repo reusable pinned to a *non-default branch* of another repo — and reported it "resolved once I
merged the workflow PR in the calling repository." Nobody in the thread reports a **SHA-pinned** cross-repo
reusable. Issue #443 is still open.

**Spike design (~3–4h):**
1. In `DriverDigital/workflows`, add a throwaway `.github/workflows/spike-claude.yml` — `workflow_call`,
   `id-token: write`, the real `claude-code-action` step, nothing else.
2. In `vite-plugin-shopify-clean`, add `.github/workflows/spike-claude-caller.yml` with the **full**
   permissions block, calling the reusable at an **explicit 40-hex SHA pin** —
   `uses: DriverDigital/workflows/.github/workflows/spike-claude.yml@<SHA>` — never `@main`. **Record that SHA
   verbatim in the run notes**, because the whole result is meaningless if the pin silently equalled HEAD.
   **Merge to the default branch** — mandatory, see "no pre-merge test path" below. Trigger the caller on
   `issues: [opened]`, matching the real `claude.yml`.
3. **Push one trivial commit to `workflows/main` first**, so the pinned SHA is provably behind `main` HEAD.
   This is the assertion nobody thinks to make: a pilot run at a pin that happens to equal `main` HEAD passes
   and then breaks the fleet on the next commit to `main`.

   > **Correction (2026-08-02).** The original draft reassured that this condition "exists naturally,"
   > because `main` @ `9b70acf` was then one untagged commit past `v1.6.0`. **That is no longer true** —
   > `main` HEAD is now exactly `a54c91e` = tag `v1.9.0`, so a pin at the current tag *equals* HEAD and the
   > spike would produce a false pass. The gap must now be created deliberately. Do not skip this step.
4. Open one issue as `driver-digital-agents` containing `@claude`.
5. **PASS** = log shows the OIDC exchange succeeding **and** a `pull_request` `opened` webhook whose
   `user.login` is literally `claude[bot]`. **FAIL** = a green run with
   `::warning::Skipping action due to workflow validation` and no PR.
6. Delete both files. Record the run URL in the release notes either way.

**If Phase 0 fails:** convert `bonsai-status-sync.yml` only, leave `claude.yml` as a full per-repo file, and
revisit when #443 closes.

### Never reach for `github_token` as an unplanned fallback — but see the note below

Anthropic's documented workaround on #443 is to supply your own `github_token`. **Never do this as an ad-hoc
fix mid-pilot.** It changes the PR author from `claude[bot]` to `driver-digital-agents`, which breaks the rail
split: `ticketed-review`'s stub gates round 1 on `pull_request.user.login == 'claude[bot]'`, and
`pr-first-review` gates on `!= 'claude[bot]'`.

> **Correction (2026-07-31).** An earlier revision of this document said such PRs would "route to the PR-first
> rail instead of the ticketed rail". That is wrong, and the truth is worse. The ticketed stub's `if:` is
> false, so the reusable is **never invoked** — no check run at all. The PR does reach `pr-first-review`, whose
> `!= 'claude[bot]'` guard now passes, but its `has_ticket` step finds the Bonsai uuid and skips. **Both rails
> end green having done nothing, and the PR is reviewed by nobody.**

**This is now a deliberate project, not a forbidden shortcut.** Dropping the Claude App and unifying on
`driver-digital-agents` is scoped in [`identity-unification-scope.md`](identity-unification-scope.md), which
fixes the rail gates as a requirement rather than discovering them as a failure. The distinction is entirely
whether the gates move in the same change.

**If that project ships first, the Phase 0 spike above ceases to exist** — no App token means no OIDC
exchange, no default-branch validation, and no `job_workflow_ref` question. The `claude.yml` stub also stops
needing `id-token: write`, which was what made it the most privileged stub in the kit. Sequencing
identity-first is therefore the cheaper order.

---

## Design decisions (already made, with reasoning)

**1. The `claude.yml` stub cannot be thin in the privilege sense.** A called workflow's permissions can only be
*downgraded*, never elevated. The stub must declare all five at workflow level:

```yaml
permissions:
  contents: write
  pull-requests: write
  issues: write
  id-token: write      # omit this and the identity DEGRADES rather than failing loudly
  actions: read
```

Two distinct failure modes, both reported verbatim on #443: with no block, `Could not fetch an OIDC token. Did
you remember to add 'id-token: write'`; with permissions in the reusable but not the caller, a hard
startup-validation error naming the exact shortfall. Make "stub declares all five verbatim" a cutover
checklist item.

**2. The actor gate goes INSIDE the reusable**, as `jobs.claude.if:`, carrying `claude.yml:90-102` and the
`67-89` comment block unchanged. The concern that this starts a runner is **incorrect for a job-level `if:`** —
a reusable's jobs are expanded into the caller's run and scheduled normally; a false job-level `if:` marks the
job skipped and no runner is provisioned, so no write-scoped token and no OAuth secret is ever materialised.
This keeps the gate in one file that a single repin updates fleet-wide, instead of a copy on each of Palmers'
8 branches. *Prove the negative during the pilot:* post a plain comment (no `@claude`) and confirm the job
shows skipped with zero runner minutes. If it unexpectedly provisions one, fall back to caller-level
`jobs.<id>.if` — same expression moved up one file, a 10-line stub edit, not a redesign.

**3. `SHOPIFY_STORE_NAME` must become a `with:` input.** A reusable-calling job may only use
`name/uses/with/secrets/strategy/needs/if/concurrency/permissions` — no `env:`, no `steps:`. So the current
job-level `env:` knob (`templates/github/claude.yml:120-128`, the file's *only* job-level env key) has nowhere
to go but `with:`. **This fixes an active latent bug:** the kit README's re-copy instruction says to preserve
Dependabot pins but says nothing about `SHOPIFY_STORE_NAME`, so the next wave that re-copies `claude.yml` into
Avara would reset `"avara"` to `""` and the provisioning step would self-skip *silently*, since it is designed
to degrade quietly when unset.

> **Correction (2026-08-02).** `SHOPIFY_STORE_NAME` now has a **second consumer**. At v1.6.0 it was read
> only by the provisioning script (`:195`, `:202-206`, `:233`). v1.8.0 also interpolates it into the audit
> **artifact name** at `templates/github/claude.yml:458`. The `inputs.shopify_store_name` value must be
> threaded to **both** sites — wiring only the provisioning step leaves the artifact named
> `shopify-audit--<run_id>-<attempt>`, which uploads successfully and is therefore another silent failure.

**4. `concurrency` stays in the stub**, workflow-level, matching all five existing stubs.

**5. Status strings, the UUID regex, and the `driver-digital-agents` + `261291955` gate stay hardcoded in the
reusables.** Making the actor gate an input would let a caller widen it.

**6. Context semantics confirmed against official docs** — all of these keep meaning exactly what they mean
today, because in a called workflow "the `github` context is always associated with the caller workflow":
- `github.event.*` — the caller's full payload, unchanged. Already proven in-repo:
  `.github/workflows/pr-first-review.yml` is `workflow_call`-only and reads `github.event.pull_request.*` in
  production at `:55`, `:56`, `:61` (the fork guard), `:80`, and `:113` (the checkout ref). If a reusable
  could not see the caller's `github.event`, the fork guard would compare an empty string and the rail would
  be broken on every run.
  > **Correction (2026-08-02).** The original draft said this contradicts a stale *"a reusable cannot
  > see `github.event`"* claim in `dependabot-report.yml`'s header. The actual comment is **narrower** than
  > that paraphrase — it says specifically `github.event.workflow_run` — and it exists in **two** files:
  > `.github/workflows/dependabot-report.yml:16-17` and `templates/github/dependabot-report.yml:6`. Both are
  > still wrong (the `github` context in a called workflow comes from the caller, so a reusable invoked from a
  > `workflow_run`-triggered stub *would* see it), but fix both, and quote them accurately. Note the *design*
  > — passing the context explicitly via `with:` — remains defensible on provenance-auditability grounds
  > (`.github/workflows/dependabot-report.yml:47-60`); only the stated justification is false.
- `github.token` — the **caller repo's** installation token, so
  `gh pr view --json closingIssuesReferences` resolves unchanged.
- `vars.BONSAI_URL` — resolves against the **caller's** repository variables. Already proven by
  `vars.PR_REVIEWER_HANDLE` inside `pr-first-review.yml`.
- `secrets: inherit` works same-org and passes org + repo secrets. Explicitly mapping a secret *not* declared
  in the callee is an error.

**7. Required-check contexts rename:** `claude` → `claude / claude`, `sync` → `sync / sync`. Silent if any
repo has one pinned as a required check. Confirm none do before the wave.

---

## Proposed interfaces

**`.github/workflows/bonsai-status-sync.yml`** — zero inputs:

```yaml
on:
  workflow_call:
    secrets:
      BONSAI_BEARER_TOKEN: { required: false }   # see open decision 4
```

**`.github/workflows/claude.yml`**:

```yaml
on:
  workflow_call:
    inputs:
      shopify_store_name: { type: string, required: false, default: '' }
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN:            { required: true }
      AGENTS_GH_PAT:                      { required: true }
      DRIVER_ENGINEERING_APP_CLIENT_ID:   { required: false }
      DRIVER_ENGINEERING_APP_CLIENT_SECRET: { required: false }
      SHOPIFY_STORE:                      { required: false }
      SHOPIFY_ALERT_WEBHOOK:              { required: false }
```

**`SHOPIFY_ALERT_WEBHOOK` is the trap in this block.** Added by v1.7.0 (`templates/github/claude.yml:191`, the
`#driver-agents-status` Slack webhook), it is an **org-level** secret — so under an *explicit* `secrets:` map
it is **not** automatically visible to the called workflow and the stub must pass it or use `secrets: inherit`.
Omit it and the guard at `:239` (`[ -n "$SHOPIFY_ALERT_WEBHOOK" ]`) simply takes the other branch: Slack
alerting on destructive Admin API calls goes **silently off fleet-wide**, no error, green run. Interacts
directly with open decision 2.

All store secrets must stay `required: false` — the script's empty-string early-exit at `:195-197` is exactly
what lets non-store repos self-skip. (The client-id/secret pair was renamed from `DRIVER_AGENTS_SCOPES_*` by
v1.9.0; live names at `:177-178`.)

`DRIVER_AGENTS_REF` moves **into** the reusable (a win — it removes half the two-files-must-match hazard).
`ANTHROPIC_API_KEY` stays comment-only (`:311`).

**On declaring secrets — the claim is true, but scope it precisely.** Every secret referenced by a workflow
**in this repo's `.github/workflows/`** must be declared under its own `on.workflow_call.secrets`, or
`lint.yml` goes red. This was challenged on review as false, on the grounds that `secrets: inherit` makes
undeclared secrets resolve at runtime. That is true *at runtime* and irrelevant *to the lint gate*: actionlint
types the `secrets` context of a `workflow_call` workflow from that file's own declaration block and never
sees the caller, so `inherit` cannot suppress the error. Reproduced against the pinned actionlint 1.7.12
(`.github/workflows/lint.yml:40`, invoked at `:64-65`):
`property "not_declared" is not defined in object type {…}` → `exit 1`. The repo already demonstrates the
split: `templates/github/pr-first-review.yml:27` is `secrets: inherit`, yet the reusable it calls still
declares both secrets at `.github/workflows/pr-first-review.yml:42-44`. The constraint does **not** apply to
`templates/github/*.yml`, which are caller stubs with no `workflow_call` trigger and therefore an untyped
`secrets` context.

### The v1.8.0 artifact leg — new since the original draft

v1.8.0 added an audit-artifact upload (`templates/github/claude.yml:454-460`, mirrored at
`templates/github/shopify-tool-smoke.yml:106-112`). The step itself moves into a reusable unchanged —
`always()`, `env.*` read from `$GITHUB_ENV`, and `upload-artifact`'s own `ACTIONS_RUNTIME_TOKEN` auth are all
unaffected by `workflow_call`. Two things do change:

- **`env.SHOPIFY_STORE_NAME` in the artifact name must become `inputs.*`** — see design decision 3 above.
- **A called workflow does not get its own run id.** `github.run_id` and `github.run_attempt` resolve to the
  **caller's** run. That is the *desirable* outcome for the collector — the artifact lands in the consuming
  repo's run, where the box's nightly `audit-publish.sh` already looks. But it degrades the collision guard
  the file calls load-bearing at `:449-452`: `run_id` + `run_attempt` no longer disambiguate *jobs within one
  run*. What makes that safe today is simply that `claude.yml` declares **exactly one job** (`jobs.claude`,
  `:65-66`) — not the concurrency group at `:61-63`, which serializes *runs* within a group and says nothing
  about jobs inside a run. Conversion removes that structural guarantee: **call the reusable from two jobs in
  one caller workflow, or matrix it, and you get two uploads with a byte-identical name — the second fails**,
  because artifacts are immutable. Write that constraint into the reusable's header.

---

## Sequencing — two independent waves, `bonsai-status-sync` first

**The Phase 0 spike gates `claude.yml` only.** `bonsai-status-sync.yml` has no OIDC path and no App token, so
nothing about the spike's outcome bears on it. If Phase 0 fails, Phases 1–3 still ship. The phase table below
is ordered by dependency, not by gating — do not read Phase 0 sitting at the top as a global hold.

`bonsai-status-sync.yml` goes first because **it is the only one of the two with any pre-merge test path at
all**. It has no OIDC path and one secret (`BONSAI_BEARER_TOKEN`,
`templates/github/bonsai-status-sync.yml:169`).

Be precise about how much of it is provable pre-merge, because it is **one leg of three**. Its `on:` block
(`:41-50`) carries `issues: [opened]`, `pull_request: [opened, reopened, ready_for_review, synchronize]`, and
`pull_request_review: [submitted]`. Only the **`pull_request` leg** runs from the PR merge ref and so tests
itself on its own cutover PR. By the same default-branch-only rule that strands `claude.yml` (see below),
`issues` and `pull_request_review` are inert on a cutover branch — and the `issues` leg is where the `@claude`
grep and the actor gate live (`:134-136`), which is the logic most worth piloting. **Plan to validate those
two legs after merge**, and say so in the cutover PR body; do not let "testable pre-merge" imply the whole
file was exercised.

Its template is **still byte-identical to the v1.6.0 draft** — sha256
`811148d08592919cfa19d202a68f0e54c705845ba8110cb42b354339310f39a0`, unchanged across `0a3934f`, `9b70acf`, and
`a54c91e`. It has no workflow- or job-level `env:` at all, so it needs **zero inputs**, and it is the one file
in this scope whose starting state is genuinely known. Only the **template** side of that is verifiable from
this repo, though: the claim that the deployed fleet copies match was verified at authoring time and is not
re-verified here — re-run `tools/fleet-pin-audit.sh` before the wave rather than trusting this line.

`claude.yml` **has no pre-merge test path**, and this must be written into the cutover PR body. Two rules
stack: (a) `issues`, `issue_comment`, `pull_request_review`, `pull_request_review_comment` only trigger from
the **default branch**, so a stub on a cutover branch is inert; (b) Anthropic's exchange requires the running
file to match the default-branch version, so forcing a run returns the 401. **A reviewer who tries the obvious
thing — `@claude` on the cutover PR — will see a red run and wrongly conclude the conversion is broken.** Say
so in the PR body. Merge on review of the diff alone; validate after merge.

| Phase | Work | Est. | Status |
|---|---|---|---|
| 1 | Convert `bonsai-status-sync.yml` + stub + docs + lint | 3h | **done 2026-08-02** |
| 2 | Pilot it (only the `pull_request` leg is testable pre-merge — see *Sequencing*) | 2h | **next** |
| 3 | Fleet wave for `bonsai-status-sync` — 18 repo@branch pairs across 11 repos | 3–4h | after Phase 2 |
| 5 | Tag + repin the kit stubs (README's mandatory 3-step release order) | 1h | with Phase 3 |
| | **Approved subtotal** | **9–10h** | Phase 1 done → **6–7h left** |
| 0 | Spike: go/no-go on OIDC-in-reusable | 3–4h | **tabled** |
| 4 | Convert `claude.yml` — move the 460 lines **faithfully** | 7–9h | **tabled** |
| 6 | Pilot `claude.yml` with the four assertions incl. pin-vs-HEAD | 4–6h | **tabled** |
| 7 | Fleet wave for `claude.yml`, same 18 pairs (10 single-branch repos incl. Avara → Palmers ×8) | 4–5h | **tabled** |
| 8 | Optional: convert `shopify-tool-smoke.yml` | 2–3h | **tabled** |
| | **Tabled subtotal** | **20–27h** | |

### Phase 1 landed 2026-08-02 — what shipped, and what deliberately did not

**Shipped:** `.github/workflows/bonsai-status-sync.yml`, the reusable. Its `jobs:` body is byte-identical to
the old copy except one added comment; actionlint + shellcheck clean; `BONSAI_BEARER_TOKEN` declared
`required: true`. Also a new `lint.yml` guard that fails the build on any kit stub carrying a placeholder pin.

**Deliberately NOT shipped: the caller stub.** A new reusable's stub cannot be pinned until the tag containing
that reusable exists, so it lands in step 2 of the release order, not here. This is the house precedent —
`dependabot-keep-current`'s reusable landed in `c362604` and its stub arrived later already carrying a real
SHA. The kit therefore still installs the 190-line copy, which still works, until the repin.

**The stub to land at repin** (replace `templates/github/bonsai-status-sync.yml` wholesale, and set the pin to
the new tag's SHA + `# vX.Y.Z`):

```yaml
name: Bonsai status sync

# CALLER STUB — install into a pipeline repo's .github/workflows/.
# Calls the central bonsai-status-sync reusable, which flips the linked Bonsai
# task's status off the GitHub issue/PR lifecycle. Inherits secrets (it needs
# BONSAI_BEARER_TOKEN, an org-level Actions secret).
#
# This REPLACED a 190-line per-repo copy (converted 2026-08-02). The status
# machine, the actor gate, the linkage logic and the cascade caveat now live in
# ONE file — see DriverDigital/workflows/.github/workflows/bonsai-status-sync.yml.
# Nothing below is repo-specific: this stub is byte-identical across the fleet.
#
# WHAT STAYS HERE, AND WHY:
#   • the TRIGGERS — a called workflow cannot declare `on:`, so the event
#     subscription is necessarily the caller's. Keep the `types:` lists exactly
#     as written; they are load-bearing (see the reusable's header for the
#     dismissed-review edge and the draft guards).
#   • `permissions:` — a called workflow's permissions can only be DOWNGRADED by
#     the caller. Declare all three or the reusable's `gh` reads 403.
#   • `concurrency:` — see the block itself; the rationale is load-bearing and
#     is NOT the same as pr-first-review's. Do not "harmonise" them.

on:
  issues:
    types: [opened]
  pull_request:
    # 'reopened' is included so a closed-then-reopened non-draft PR re-asserts Internal Review
    # (a bare reopen fires neither 'opened' nor 'synchronize' — without it the flip is silently
    # dropped). The draft guard in the reusable still keeps a reopened draft PR as WIP.
    types: [opened, reopened, ready_for_review, synchronize]
  pull_request_review:
    types: [submitted]

permissions:
  contents: read
  issues: read
  pull-requests: read

# One status flip per ref at a time — a rapid push/review burst can't race conflicting writes
# onto the same task through the single shared browser lock; the backend browser lock serializes
# the actual writes. Deliberately per-ref, NOT repo-wide: with cancel-in-progress:false GitHub
# keeps only ONE pending run per group and cancels the prior pending one, so a repo-wide group
# would let an unrelated task's flip silently cancel another's during a burst. Cross-ref ordering
# (a late issue->In Progress landing after a PR->Internal Review) is a narrow window — the issue
# event precedes the PR by the whole implementation time — and self-heals: the next PR event
# re-flips.
# DO NOT set cancel-in-progress: true here to match pr-first-review's stub — that rail reviews
# once and is safe to cancel; this one WRITES STATUS and a cancelled flip is a dropped write.
concurrency:
  group: bonsai-status-${{ github.event.pull_request.number || github.event.issue.number }}
  cancel-in-progress: false

jobs:
  sync:
    # NOTE: the required-status-check context for this job is `sync / sync` (caller job id /
    # reusable job id), NOT the bare `sync` it was as a full workflow. Verified 2026-08-02 that
    # no branch in the org pins either, so this rename breaks nothing — re-check before adding one.
    uses: DriverDigital/workflows/.github/workflows/bonsai-status-sync.yml@0000000000000000000000000000000000000000 # UNREPINNED — lint.yml blocks merge until this is a real tag SHA
    # Explicit, NOT `secrets: inherit`. Two reasons: (1) `inherit` passes whatever set exists, which
    # defeats the reusable's `required: true` — a missing secret would reach the curl and surface as
    # an opaque 401 on the first real flip instead of failing at startup; (2) least privilege — this
    # rail needs one secret, and `inherit` would hand a centrally-pinned file that fires on
    # `issues: [opened]` every org secret the repo holds (AGENTS_GH_PAT, CLAUDE_CODE_OAUTH_TOKEN,
    # the store credentials). Matches ticketed-review.yml's stub, which enumerates for the same reason.
    secrets:
      BONSAI_BEARER_TOKEN: ${{ secrets.BONSAI_BEARER_TOKEN }}
```

Then update these three, which are correct today and become wrong the moment the stub lands:
- `templates/github/README.md` — move `bonsai-status-sync.yml` from *Full workflows* to *Caller stubs*, and
  rewrite onboarding step 5 ("Confirm the board strings … update them **here**") — after the swap the status
  strings live only in the central reusable, so a board rename is a kit release + fleet repin, not a local edit.
- `README.md` — the kit paragraph, and "Repin the five caller stubs" → six.
- `.github/workflows/lint.yml` header — "six reusables" is already correct; check the count again if another lands.

### Phase 2 pilot — assert the one thing that is still assumed

Everything else in the conversion was verified statically. `vars.BONSAI_URL` was not: the claim that a
repository *variable* resolves against the **caller** rests on `vars.PR_REVIEWER_HANDLE` working inside
`.github/workflows/pr-first-review.yml:192`, which only proves it does not error — if no repo has ever set
that variable, only the untaken fallback branch has run. If the assumption is wrong, `vars.BONSAI_URL`
resolves against `DriverDigital/workflows` (where it does not exist) and silently falls back to the hardcoded
default — and that default now lives in ONE file, so a tunnel move would break all 18 targets together with
the per-repo escape hatch being the untested path.

**Assertion:** on the pilot repo, set `BONSAI_URL` as a repository variable to a deliberately bogus host and
confirm the run goes **red**. Thirty seconds, and it converts the assumption into evidence.

**Phase 5 moved up.** It was written as "tag + repin" after the `claude.yml` conversion, but the
`bonsai-status-sync` half needs its own tag and repin to be usable at all — the new stub ships with a
placeholder pin. Do it as part of the Phase 3 wave, not after it.

**If identity unification ships first, Phase 0 disappears and the total is 26–33h.** And Phases 1–3 (8–11h)
depend on neither Phase 0 nor the identity decision — that portion is startable now.

*Estimates grew on the 2026-08-02 refresh: Phase 4's payload is 460 lines rather than 404 (6–8h → 7–9h) and
Phase 8's `shopify-tool-smoke.yml` went 89 → 112 lines (2h → 2–3h). The v1.6.0 table also stated 28–36h while
its own max column summed to 35.*

Phase 4 note: **63%** of `claude.yml` is comments (291 of 460 lines — it was 67% at v1.6.0), and they are the
institutional memory — the 2026-06-19 actor-gate incident, the `persist-credentials` 403 on private repos, the
foundrae #148 prompt-hijack, the Avara #143 install blip. Budget for moving them faithfully, not cut-and-paste.

---

## Pilot design — two legs, four assertions

> **This section was written for `claude.yml`. For the `bonsai-status-sync` pilot (Phase 2), run the legs in
> the OPPOSITE order — private first.** The public-first reasoning below is specific to `claude.yml`'s
> App-token path and its `persist-credentials` private-fetch failure, neither of which exists in
> `bonsai-status-sync.yml`. What is untested for *this* file is a **private consumer resolving a public
> cross-repo reusable**, and 10 of the 11 target repos are private — so `foundrae-blackridge (staging)` is the
> leg that can actually fail, and `vite-plugin-shopify-clean` is the cheap confirmation afterwards. The
> "do not pilot here" list below still applies for a different reason: those repos are fine for *this* rail
> (it does not need `claude[bot]` history), but keep the pilot on the designated test beds anyway.
>
> Assertions for this rail are in *Phase 2 pilot* above — the `vars.BONSAI_URL` red-run check is the one that
> converts the last assumption into evidence. The four assertions below are `claude.yml`'s and do not apply.

**Leg 1: `vite-plugin-shopify-clean`.** Public, single `main`, both files installed, **7 prior `claude[bot]`
PRs** so the App-token path is already proven there, no client and no store secrets, and public logs are
readable without access friction.

**Leg 2: `foundrae-blackridge` (`staging`).** Private, 4 prior `claude[bot]` PRs, already the designated live
test bed. **Only this leg exercises the private-repo fetch path** — the `persist-credentials` note records
that stripping the credential "works on a PUBLIC repo (anonymous fetch) but 403s on a PRIVATE repo", so a
public-only pilot is a false pass for that specific failure.

Do **not** pilot in `plugins`, `client-workspaces` or `studio-sulzer`: all three carry the full kit but have
**zero `claude[bot]` PRs ever**, so you cannot tell a conversion failure from a repo that never had the App
installed. Avara is the worst first choice (only non-uniform file, plus real long-lived store credentials);
Palmers second-worst (8 branches, one `claude[bot]` PR ever).

**The four assertions** — all mechanical, all required:
1. **App token** — log contains the OIDC exchange succeeding, **and** the PR webhook's `user.login` is
   literally `claude[bot]`. Not "a PR exists", not a prefill link, not `app/claude` from `gh pr view`.
2. **Cascade** — a `bonsai-status-sync` run exists whose triggering event is `pull_request`/`opened`, and the
   Bonsai task reads **Internal Review**.
3. **No double-fire** — `gh run list --workflow=claude.yml` shows exactly one run per `@claude` event, and
   exactly one `claude[bot]` PR per issue.
4. **Pin-vs-HEAD** — the pinned SHA is provably behind `workflows/main` HEAD, and assertion 1 still passes.

**Cutover hazard (double-fire):** the stub keeps the **same filename** (`.github/workflows/claude.yml`), so
the old full workflow is *replaced*, not accompanied. That makes double-firing structurally impossible rather
than merely avoided — but assert it anyway (assertion 3).

**Rollback:** all four `claude.yml` triggers are default-branch-only, so a revert has no effect until it
merges — and the kit mandates a human approver on every consuming default branch. So rollback is a review
round-trip on a client repo, not a push. **Pre-stage it:** keep the pre-cutover content on a branch named
`rollback/claude-yml-pre-reusable` in each target so the revert is a one-click PR. Name the out-of-hours
approver per repo. The strongest safety property of the same-filename design: the old full workflow is
entirely self-contained and depends on nothing in this repo, so revert is complete and instant once merged.

---

## Open decisions needed before Phase 1

1. **Convert `shopify-tool-smoke.yml` in the same wave — or make the `lint.yml` assertion mandatory.** This is
   no longer the optional add-on the first draft described. The two `DRIVER_AGENTS_REF` pins are currently in
   lockstep (`templates/github/claude.yml:186` and `templates/github/shopify-tool-smoke.yml:46`, both
   `0bbb125f36a6cae7bb211145efb6e57f70a883e9`), and the invariant is written into the file as "keep in lockstep
   with `claude.yml`'s `DRIVER_AGENTS_REF` **in this same repo**." Converting `claude.yml` alone **breaks that
   by construction** — the reusable would pin centrally while the smoke test pins whatever the last fleet wave
   copied. The file also carries its own hand-edited job-level `SHOPIFY_STORE_NAME` (`:31`), so it is a third
   copied-and-hand-edited file, not merely a third pin site. Converting it costs ~2–3h
   (`workflow_dispatch`-only, ~15-line stub). *If cut:* the one-line `lint.yml` assertion that the two values
   match stops being a nice-to-have and becomes the only thing preventing silent divergence.
2. **`secrets: inherit` vs explicit mapping** for the `claude` stub — pick which silent failure you would
   rather not have, and say why in the PR body. Not a stylistic toss-up: with an explicit map the
   **org-level** `SHOPIFY_ALERT_WEBHOOK` is not automatically visible to the called workflow and must be
   listed, and forgetting it disables Slack alerting fleet-wide on a green run (see *Proposed interfaces*).
   `inherit` makes that omission impossible and matches `pr-first-review`; explicit makes the
   `ANTHROPIC_API_KEY` precedence trap impossible.
3. ~~**Reconcile the target count.**~~ **CLOSED 2026-08-02 — verified against the org.** All three numbers
   were right; they count different things. Use these definitions and put them next to the number:
   - **18 repo@branch pairs, across 11 distinct repos**, carry `bonsai-status-sync.yml` on a long-lived
     branch. **This is the Phase 3 wave size.** Palmers contributes 8 of the 18.
   - **21** is the *repin-wave* target list (what `tools/fleet-pin-audit.sh` enumerates) — it additionally
     counts `Team-Laird@develop`, `The-Gathery@develop` and `driver-bonsai-mcp@main`, which carry only the
     `pr-first-review` stub and neither of the two full workflows. That is the number
     `identity-unification-scope.md` correctly uses.
   - The pilot section's "10 single-branch repos → Avara → Palmers ×8" was **off by one**: there are 10
     single-branch kit repos *including* Avara, so 10 + 8 = 18.
   - `claude.yml` sits on **exactly the same 18 pairs** — verified branch-by-branch across all 618 org
     branches, zero rows where one file is present without the other. A wave touching one can touch both.
4. ~~**`BONSAI_BEARER_TOKEN`: `required: false` vs `required: true`.**~~ **CLOSED 2026-08-02 —
   `required: true`.** It is an org-level Actions secret available to every consuming repo, so there is no
   legitimate caller that installs this rail without it. `required: true` fails at startup validation naming
   the shortfall; `required: false` would let the run reach the `curl` and surface as an opaque 401 mid-run.
   Also matches `ticketed-review`. One line to flip if that reasoning ever stops holding.
5. **Confirm the Claude GitHub App is installed on all kit repos**, not just the 4 with prior `claude[bot]`
   PRs. If it is missing in `plugins` / `client-workspaces` / `studio-sulzer`, they fail on their first real
   ticket after the wave and it gets blamed on the conversion. **Applies to the tabled `claude.yml` half
   only** — not a blocker for Phases 1–3.
6. ~~**Confirm no repo pins `claude` or `sync` as a required status check.**~~ **CLOSED 2026-08-02 — none
   do, so the `sync` → `sync / sync` rename breaks nothing.** Verified rather than assumed: all 42 protected
   branches across the 15 kit-touching repos were checked. 36 have no `required_status_checks` block at all;
   6 have the block with `strict: true` but **both** `contexts: []` and `checks: []` (the newer `checks[]`
   array was checked too — a `contexts`-only query would have missed a modern pin). Org rulesets are empty,
   and the single repo ruleset (`vite-plugin-shopify-clean`) has only a Copilot-review rule. Two live kit
   branches are **unprotected entirely** — `studio-sulzer@main` and `Team-Laird@develop` — which is worth
   knowing independently of this question.
7. **Pin policy:** immutable SHAs vs a moving `@v1` tag for this first-party repo. A moving tag removes waves
   entirely, at the cost of deleting the only staging gate between a merge to `main` and the fleet. Genuine
   tradeoff — decide deliberately, do not drift into it.

---

## Provenance

Researched 2026-07-31 by five parallel agents across: the OIDC/App-token path, event and gate semantics, the
`workflow_call` interface, `bonsai-status-sync` specifics, and migration risk. Every hard-blocker claim was
then put to an adversarial challenge agent instructed to refute it; **all six were refuted**. Doc claims are
sourced to official GitHub Actions docs, `anthropics/claude-code-action` source at the pinned SHA
`be7b93b1907a4abad570368f3c74b6fe3807510b`, issue #443, and this repo's own files.

**Refreshed 2026-08-02** against `main` @ `a54c91e` (v1.9.0), after three releases landed underneath the draft.
Every in-repo `file:line` citation was re-read at that SHA and every arithmetic claim recomputed; citations are
now path-qualified. Five findings from the CodeRabbit review of PR #21 were adopted and one **rejected on
evidence** — see *On declaring secrets* above. The **external** citations into `anthropics/claude-code-action`
were *not* re-verified; they remain as originally researched at the pinned SHA.
