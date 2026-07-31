# Scope: convert `claude.yml` + `bonsai-status-sync.yml` into reusable workflows

**Status:** scoped, not started. **Written:** 2026-07-31, against `main` @ `9b70acf` (tag `v1.6.0` = `0a3934f`).

The README has flagged this as "future work" since the repo split. This document is the scope to execute it.

---

## Why

Of the 837-line kit, **594 lines (71%) are the two files that are copied verbatim rather than called** —
`claude.yml` (404) and `bonsai-status-sync.yml` (190). The five caller stubs total 154 lines and are
mechanical.

Every drift incident traces to that split. Avara shipped the prompt-hijack bug because `claude.yml` is
copied, so a subset of upstream changes could be hand-carried into it. The store handle needs preserving on
re-copy because it is a hand-edited line in a copied file. `DRIVER_AGENTS_REF` is duplicated because it lives
in copied files.

**Conversion does not eliminate waves** — SHA-pinned stubs still need a pin bump per change. It changes what a
wave *is*: from re-copying 594 lines into 18 targets while hand-preserving per-repo edits, to changing one SHA
string. Drift becomes structurally impossible because there is no downstream logic to edit.

Secondary win: `actions/checkout` and `claude-code-action` move out of `templates/` and into
`.github/workflows/`, which `.github/dependabot.yml` (`directory: "/"`) actually scans — converting two
documented manual pins into bot-managed ones.

---

## Verdict: viable, gated on one spike

Six claims were raised as hard blockers during research. **All six were refuted under adversarial challenge.**
Nothing structurally prevents this. But one undocumented behaviour decides whether `claude.yml` ships in this
form at all, and it must be settled before any other work.

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
   permissions block. **Merge to the default branch** — mandatory, see "no pre-merge test path" below.
3. **Push one trivial commit to `workflows/main` first**, so the pinned SHA is provably behind `main` HEAD.
   This is the assertion nobody thinks to make: a pilot run at a pin that happens to equal `main` HEAD passes
   and then breaks the fleet on the next commit to `main`. *(As of writing, `main` @ `9b70acf` is already one
   untagged commit past `v1.6.0` @ `0a3934f` — the condition exists naturally; make it deliberate.)*
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

**If that project ships first, Phase 0 below ceases to exist** — no App token means no OIDC exchange, no
default-branch validation, and no `job_workflow_ref` question. The `claude.yml` stub also stops needing
`id-token: write`, which was what made it the most privileged stub in the kit. Sequencing identity-first is
therefore the cheaper order.

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
job-level `env:` knob has nowhere to go but `with:`. **This fixes an active latent bug:** the kit README's
re-copy instruction says to preserve Dependabot pins but says nothing about `SHOPIFY_STORE_NAME`, so the next
wave that re-copies `claude.yml` into Avara would reset `"avara"` to `""` and the provisioning step would
self-skip *silently*, since it is designed to degrade quietly when unset.

**4. `concurrency` stays in the stub**, workflow-level, matching all five existing stubs.

**5. Status strings, the UUID regex, and the `driver-digital-agents` + `261291955` gate stay hardcoded in the
reusables.** Making the actor gate an input would let a caller widen it.

**6. Context semantics confirmed against official docs** — all of these keep meaning exactly what they mean
today, because in a called workflow "the `github` context is always associated with the caller workflow":
- `github.event.*` — the caller's full payload, unchanged. Already proven in-repo: `pr-first-review.yml` reads
  `github.event.pull_request.*` in production (contradicting the stale "reusable cannot see `github.event`"
  claim in `dependabot-report.yml`'s header — worth correcting).
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
      BONSAI_BEARER_TOKEN: { required: false }   # see open decision 3
```

**`.github/workflows/claude.yml`**:

```yaml
on:
  workflow_call:
    inputs:
      shopify_store_name: { type: string, required: false, default: '' }
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN:          { required: true }
      AGENTS_GH_PAT:                    { required: true }
      DRIVER_AGENTS_SCOPES_CLIENT_ID:   { required: false }
      DRIVER_AGENTS_SCOPES_CLIENT_SECRET: { required: false }
      SHOPIFY_STORE:                    { required: false }
```

`DRIVER_AGENTS_REF` moves **into** the reusable (a win — it removes half the two-files-must-match hazard).
`ANTHROPIC_API_KEY` stays comment-only. Every secret the reusable references must be **declared** under
`on.workflow_call.secrets` or this repo's own `lint.yml` goes red.

---

## Sequencing — two independent waves, `bonsai-status-sync` first

`bonsai-status-sync.yml` goes first because **it can be proven pre-merge**. Its `pull_request` trigger runs
from the PR merge ref, so its own cutover PR tests it. It has no OIDC path, one secret, and its 18 deployed
copies are currently **byte-identical** to the template (sha256 `811148d0…`, verified) — a genuinely known
starting state.

`claude.yml` **has no pre-merge test path**, and this must be written into the cutover PR body. Two rules
stack: (a) `issues`, `issue_comment`, `pull_request_review`, `pull_request_review_comment` only trigger from
the **default branch**, so a stub on a cutover branch is inert; (b) Anthropic's exchange requires the running
file to match the default-branch version, so forcing a run returns the 401. **A reviewer who tries the obvious
thing — `@claude` on the cutover PR — will see a red run and wrongly conclude the conversion is broken.** Say
so in the PR body. Merge on review of the diff alone; validate after merge.

| Phase | Work | Est. |
|---|---|---|
| 0 | Spike: go/no-go on OIDC-in-reusable (see above) | 3–4h |
| 1 | Convert `bonsai-status-sync.yml` + stub + docs + lint | 3h |
| 2 | Pilot it (public leg + private leg; testable pre-merge) | 2h |
| 3 | Fleet wave for `bonsai-status-sync`, 18 targets | 3–4h |
| 4 | Convert `claude.yml` — move the 404 lines **faithfully** | 6–8h |
| 5 | Tag + repin kit stubs (README's mandatory 3-step release order) | 1h |
| 6 | Pilot `claude.yml` with the four assertions incl. pin-vs-HEAD | 4–6h |
| 7 | Fleet wave: 10 single-branch repos → Avara → Palmers as one 8-branch batch | 4–5h |
| 8 | Optional: convert `shopify-tool-smoke.yml` | 2h |
| | **Total** | **28–36h** |

Phase 4 note: roughly 60% of `claude.yml` is comments, and they are the institutional memory — the 2026-06-19
actor-gate incident, the `persist-credentials` 403 on private repos, the foundrae #148 prompt-hijack, the
Avara #143 install blip. Budget for moving them faithfully, not cut-and-paste.

---

## Pilot design — two legs, four assertions

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

1. **Is `shopify-tool-smoke.yml` in this wave?** It is the difference between a two-way and a **three-way**
   `DRIVER_AGENTS_REF` lockstep. After conversion the pin lives in the reusable, while the smoke test stays a
   full per-repo kit file with a deployed copy in Avara — so bumping it would mean three places, the third
   being a fleet operation. Converting it (~2h, `workflow_dispatch`-only, ~15-line stub) collapses it back to
   one. *If cut:* add a one-line assertion to `lint.yml` that the two `DRIVER_AGENTS_REF` values match — that
   job already exists and already fails on kit problems.
2. **`secrets: inherit` vs explicit mapping** for the `claude` stub. `inherit` is simpler and matches
   `pr-first-review`; explicit is more defensive about the `ANTHROPIC_API_KEY` precedence trap.
3. **`BONSAI_BEARER_TOKEN`: `required: false`** (recommended) **vs `required: true`** (matching
   `ticketed-review`). This is the only interface choice with a silent-failure downside.
4. **Confirm the Claude GitHub App is installed on all kit repos**, not just the 4 with prior `claude[bot]`
   PRs. If it is missing in `plugins` / `client-workspaces` / `studio-sulzer`, they fail on their first real
   ticket after the wave and it gets blamed on the conversion.
5. **Confirm no repo pins `claude` or `sync` as a required status check** (expected: none, but the rename is
   silent if one does).
6. **Pin policy:** immutable SHAs vs a moving `@v1` tag for this first-party repo. A moving tag removes waves
   entirely, at the cost of deleting the only staging gate between a merge to `main` and the fleet. Genuine
   tradeoff — decide deliberately, do not drift into it.

---

## Provenance

Researched 2026-07-31 by five parallel agents across: the OIDC/App-token path, event and gate semantics, the
`workflow_call` interface, `bonsai-status-sync` specifics, and migration risk. Every hard-blocker claim was
then put to an adversarial challenge agent instructed to refute it; **all six were refuted**. Doc claims are
sourced to official GitHub Actions docs, `anthropics/claude-code-action` source at the pinned SHA
`be7b93b1907a4abad570368f3c74b6fe3807510b`, issue #443, and this repo's own files.
