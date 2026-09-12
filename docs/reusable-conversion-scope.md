# Scope: convert `claude.yml` into a reusable workflow

**Status:** TABLED. **Written:** 2026-07-31 against `main` @ `9b70acf` (v1.6.0); refreshed 2026-08-02
(v1.9.0, then v1.11.0). **Citations re-verified 2026-08-22 at v1.13.0, where
`templates/github/claude.yml` is 500 lines.** They are path-qualified: several filenames exist in both
`templates/github/` (short caller stubs) and `.github/workflows/` (long reusables) with entirely
different content.

*The `bonsai-status-sync.yml` half of this project shipped at `v1.11.0` (waved 2026-08-02) and was
**retired outright at `v1.13.0`** — the dispatcher in `driver-agents` polls Bonsai status now. Its
sections have been removed from this document; what remains is the `claude.yml` half.*

> ## Decision — Maria, 2026-08-02: TABLED
>
> **`claude.yml` — Phase 0 and Phases 4–8.** Whether Claude App token minting survives inside a
> cross-repo reusable is a question for another day. `claude.yml` stays a full per-repo file, and remains
> the kit's one drift surface. Do not start Phase 4 without re-opening this decision.
>
> **DEFERRED — [`identity-unification-scope.md`](identity-unification-scope.md).** Not ready to drop the
> Claude App, so the Phase 0 spike is *not* retired by that project shipping first.

### Research update — 2026-08-22 (recommendation; the decision stays Maria's)

Three things moved. None of them flips the status on its own.

- **The OIDC blocker is weaker than this document says.** On claude-code-action#443, `SHxKM` ran a caller
  stub into a cross-repo reusable pinned to a **non-default branch** of another org repo, and it worked
  once the caller merged. A SHA pin behind `main` and a non-default-branch ref are the same failure class
  — "not the default-branch version of the reusable" — so the Phase 0 spike is now a **confirmation**
  rather than a go/no-go.
- **A new risk, and it is the house failure mode.** Since claude-code-action PR #1417 (merged 2026-06-17)
  a workflow-validation failure is no longer a red 401: it becomes a `WorkflowValidationSkipError` that
  emits `::warning::Skipping action due to workflow validation` and ends the run **green**. The kit's pin
  (`d40ddef`, 2026-08-18) is well past that merge. If the reusable *is* validated, every `@claude` across
  the full-kit pairs is a green run that opens no PR and alerts nobody — foundrae #148 at fleet scale.
  Canary first, and **assert that warning string is absent**; neither is optional.
- **The business case shrank.** "A wave is re-copying the whole file while hand-preserving per-repo edits"
  stopped being true at v1.13.0 — `tools/fleet-wave.sh` does exactly that mechanically and
  `fleet-pin-audit.sh` compares whole-file content. What is left of the case: churn (`claude.yml` changed
  in 6 of the last 8 releases) and one central `DRIVER_AGENTS_REF` — the three action refs left the case
  when the kit floated them on major tags. Effort is unchanged at **20–27h**.

---

## Why

`claude.yml` is **500 of the kit's 758 `.yml` lines** and, with `shopify-tool-smoke.yml` (112), the only
copied-verbatim file carrying per-repo state — the rest is three mechanical caller stubs (78) and `lint.yml`
(68).

Every drift incident traces to that split. Avara shipped the prompt-hijack bug because `claude.yml` is
copied, so a subset of upstream changes could be hand-carried into it. The store handle needs preserving on
re-copy because it is a hand-edited line in a copied file. `DRIVER_AGENTS_REF` is duplicated because it lives
in copied files.

**Conversion does not eliminate waves** — SHA-pinned stubs still need a pin bump per change. It changes what a
wave *is*: from copying a 500-line file into every target and restoring its per-repo edit, to changing one
SHA string. (Since v1.13.0 `tools/fleet-wave.sh` does the copy mechanically, which is most of that win
already — see the research update above.)

**Implementation drift becomes structurally impossible** — there is no downstream logic left to edit. Be
precise about the scope of that claim: caller *configuration* drift does not disappear. `SHOPIFY_STORE_NAME`,
`permissions:`, `concurrency:`, and the secret mapping still live in each repo's stub and can still diverge,
and `DRIVER_AGENTS_REF` stays hand-edited fleet-wide for as long as `shopify-tool-smoke.yml` remains a copied
file (open decision 1). What conversion removes is the *logic* that a wave could hand-carry a subset of —
which is the specific failure that produced the Avara incident.

Secondary win, gone: the three third-party action refs in `templates/github/claude.yml` float on major
tags now, so nothing there is a manual pin for the conversion to move; `DRIVER_AGENTS_REF` is the one
central pin left.

---

## Verdict: viable, gated on one spike

Six claims were raised as hard blockers during research. **All six were refuted under adversarial challenge.**
Nothing structurally prevents this. But one undocumented behaviour decides whether `claude.yml` ships in this
form at all, and it must be settled before **any work on `claude.yml`**.

### Phase 0 spike — now a confirmation, not a go/no-go

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
merged the workflow PR in the calling repository." Issue #443 is still open. See the research update above:
that report answers more of the question than this paragraph credits.

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

**If Phase 0 fails:** leave `claude.yml` as a full per-repo file and revisit when #443 closes.

### Never reach for `github_token` as an unplanned fallback — but see the note below

Anthropic's documented workaround on #443 is to supply your own `github_token`. **Never do this as an ad-hoc
fix mid-pilot.** It changes the PR author from `claude[bot]` to `driver-digital-agents`. Until v1.12.0 that
also broke the rail split — both review rails gated on `claude[bot]` and a PAT-authored PR ended up reviewed
by nobody, green. Those rails are retired, so what is left is an unannounced identity change made under
pressure, which is reason enough not to do it here.

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

**2. The actor gate goes INSIDE the reusable**, as `jobs.claude.if:`, carrying `claude.yml:93-105` and the
`70-92` comment block unchanged. The concern that this starts a runner is **incorrect for a job-level `if:`** —
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
> only by the provisioning script (`:200`, `:207-211`, `:238`). v1.8.0 also interpolates it into the audit
> **artifact name** at `templates/github/claude.yml:498`. The `inputs.shopify_store_name` value must be
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
  > **Correction (2026-08-02, applied 2026-09-10).** Both `dependabot-report.yml` headers — the reusable's
  > and the stub's — justified the explicit `with:` inputs with "a reusable cannot see
  > `github.event.workflow_run`", which the rule above makes false. The comments now give the real reason:
  > the *design* — passing the context explicitly — stands on provenance-auditability grounds
  > (`.github/workflows/dependabot-report.yml:47-60`); only the stated justification was wrong.
- `github.token` — the **caller repo's** installation token, so
  `gh pr view --json closingIssuesReferences` resolves unchanged.
- `vars.*` — repository variables resolve against the **caller**. Proven at the v1.11.0 pilot, along with
  the two design lessons that outlived it —
  [`fleet-operations.md`](fleet-operations.md#piloting-a-cross-repo-reusable).
- `secrets: inherit` works same-org and passes org + repo secrets. Explicitly mapping a secret *not* declared
  in the callee is an error.

**7. Required-check context renames:** `claude` → `claude / claude`. Silent if any repo has it pinned as a
required check. Confirm none do before the wave.

---

## Proposed interfaces

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

**`SHOPIFY_ALERT_WEBHOOK` is the trap in this block.** Added by v1.7.0 (`templates/github/claude.yml:196`, the
`#driver-agents-status` Slack webhook), it is an **org-level** secret — so under an *explicit* `secrets:` map
it is **not** automatically visible to the called workflow and the stub must pass it or use `secrets: inherit`.
Omit it and the guard at `:244` (`[ -n "$SHOPIFY_ALERT_WEBHOOK" ]`) simply takes the other branch: Slack
alerting on destructive Admin API calls goes **silently off fleet-wide**, no error, green run. Interacts
directly with open decision 2.

All store secrets must stay `required: false` — the script's empty-string early-exit at `:200-202` is exactly
what lets non-store repos self-skip. (The client-id/secret pair was renamed from `DRIVER_AGENTS_SCOPES_*` by
v1.9.0; live names at `:177-178`.)

`DRIVER_AGENTS_REF` moves **into** the reusable (a win — it removes half the two-files-must-match hazard).
`ANTHROPIC_API_KEY` stays comment-only (`:327`).

**On declaring secrets — the claim is true, but scope it precisely.** Every secret referenced by a workflow
**in this repo's `.github/workflows/`** must be declared under its own `on.workflow_call.secrets`, or
`lint.yml` goes red. This was challenged on review as false, on the grounds that `secrets: inherit` makes
undeclared secrets resolve at runtime. That is true *at runtime* and irrelevant *to the lint gate*: actionlint
types the `secrets` context of a `workflow_call` workflow from that file's own declaration block and never
sees the caller, so `inherit` cannot suppress the error. Reproduced against the pinned actionlint 1.7.12
(`.github/workflows/lint.yml:40`, invoked at `:64-65`):
`property "not_declared" is not defined in object type {…}` → `exit 1`. The repo already demonstrates the
split: the retired `pr-first-review` stub was `secrets: inherit`, yet the reusable it called still declares
both secrets at `.github/workflows/pr-first-review.yml:51-53`. The constraint does **not** apply to
`templates/github/*.yml`, which are caller stubs with no `workflow_call` trigger and therefore an untyped
`secrets` context.

### The v1.8.0 artifact leg — new since the original draft

v1.8.0 added an audit-artifact upload (`templates/github/claude.yml:494-500`, mirrored at
`templates/github/shopify-tool-smoke.yml:106-112`). The step itself moves into a reusable unchanged —
`always()`, `env.*` read from `$GITHUB_ENV`, and `upload-artifact`'s own `ACTIONS_RUNTIME_TOKEN` auth are all
unaffected by `workflow_call`. Two things do change:

- **`env.SHOPIFY_STORE_NAME` in the artifact name must become `inputs.*`** — see design decision 3 above.
- **A called workflow does not get its own run id.** `github.run_id` and `github.run_attempt` resolve to the
  **caller's** run. That is the *desirable* outcome for the collector — the artifact lands in the consuming
  repo's run, where the box's nightly `audit-publish.sh` already looks. But it degrades the collision guard
  the file calls load-bearing at `:490-493`: `run_id` + `run_attempt` no longer disambiguate *jobs within one
  run*. What makes that safe today is simply that `claude.yml` declares **exactly one job** (`jobs.claude`,
  `:68-69`) — not the concurrency group at `:64-66`, which serializes *runs* within a group and says nothing
  about jobs inside a run. Conversion removes that structural guarantee: **call the reusable from two jobs in
  one caller workflow, or matrix it, and you get two uploads with a byte-identical name — the second fails**,
  because artifacts are immutable. Write that constraint into the reusable's header.

---

## Sequencing

`claude.yml` **has no pre-merge test path**, and this must be written into the cutover PR body. Two rules
stack: (a) `issues`, `issue_comment`, `pull_request_review`, `pull_request_review_comment` only trigger from
the **default branch**, so a stub on a cutover branch is inert; (b) Anthropic's exchange requires the running
file to match the default-branch version, so forcing a run returns the 401. **A reviewer who tries the obvious
thing — `@claude` on the cutover PR — will see a red run and wrongly conclude the conversion is broken.** Say
so in the PR body. Merge on review of the diff alone; validate after merge.

| Phase | Work | Est. | Status |
|---|---|---|---|
| 0 | Spike: confirm OIDC-in-reusable (see the research update) | 3–4h | **tabled** |
| 4 | Convert `claude.yml` — move the 500 lines **faithfully** | 7–9h | **tabled** |
| 6 | Pilot `claude.yml` with the four assertions incl. pin-vs-HEAD | 4–6h | **tabled** |
| 7 | Fleet wave for `claude.yml`, the full-kit pairs ([`fleet-operations.md`](fleet-operations.md#the-fleet)) | 4–5h | **tabled** |
| 8 | Optional: convert `shopify-tool-smoke.yml` | 2–3h | **tabled** |
| | **Tabled subtotal** | **20–27h** | |

**If identity unification ships first, Phase 0 disappears** and 17–23h of the tabled subtotal remains.

Phase 4 note: **66%** of `claude.yml` is comments (329 of 500 lines), and they are the
institutional memory — the 2026-06-19 actor-gate incident, the `persist-credentials` 403 on private repos, the
foundrae #148 prompt-hijack, the Avara #143 install blip. Budget for moving them faithfully, not cut-and-paste.

---

## Pilot design — two legs, four assertions

**Leg 1: `vite-plugin-shopify-clean`.** Public, single `main`, the kit installed, **7 prior `claude[bot]`
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
   literally `claude[bot]`, **and** the log carries no
   `::warning::Skipping action due to workflow validation` line (see the research update: that warning is a
   green run that did nothing).
2. **Cascade** — the dispatcher's poll moves the Bonsai task to **Internal Review**.
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

## Open decisions needed before Phase 4

1. **Convert `shopify-tool-smoke.yml` in the same wave — or make the `lint.yml` assertion mandatory.** This is
   no longer the optional add-on the first draft described. The two `DRIVER_AGENTS_REF` pins are currently in
   lockstep (`templates/github/claude.yml:191` and `templates/github/shopify-tool-smoke.yml:46`, both
   `4d633714ce0a3c9bf7ec87cfcfb8b13ceaf8240c` as of the 2026-08-02 bump), and the invariant is written into the file as "keep in lockstep
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
   `inherit` makes that omission impossible and matched the retired `pr-first-review` stub; explicit makes the
   `ANTHROPIC_API_KEY` precedence trap impossible.
3. ~~**Reconcile the target count.**~~ **CLOSED 2026-08-02.** Two numbers are both correct and count
   different things — the wave size and the repin-target list. `docs/fleet-operations.md`'s
   [fleet table](fleet-operations.md#the-fleet) is the single home for both; take them from there and put
   the definition next to the number.
4. **Confirm the Claude GitHub App is installed on all kit repos**, not just the 4 with prior `claude[bot]`
   PRs. If it is missing in `plugins` / `client-workspaces` / `studio-sulzer`, they fail on their first real
   ticket after the wave and it gets blamed on the conversion.
5. ~~**Confirm no repo pins `claude` as a required status check.**~~ **CLOSED 2026-08-02 — none do, so the
   `claude` → `claude / claude` rename breaks nothing.** Verified rather than assumed: all 42 protected
   branches across the 15 kit-touching repos were checked. 36 have no `required_status_checks` block at all;
   6 have the block with `strict: true` but **both** `contexts: []` and `checks: []` (the newer `checks[]`
   array was checked too — a `contexts`-only query would have missed a modern pin). Org rulesets are empty,
   and the single repo ruleset (`vite-plugin-shopify-clean`) has only a Copilot-review rule. Two live kit
   branches are **unprotected entirely** — `studio-sulzer@main` and `Team-Laird@develop` — which is worth
   knowing independently of this question.
6. **Pin policy:** immutable SHAs vs a moving `@v1` tag for this first-party repo. A moving tag removes waves
   entirely, at the cost of deleting the only staging gate between a merge to `main` and the fleet. Genuine
   tradeoff — decide deliberately, do not drift into it.
   > **Assessed 2026-09-10, declined for now.** The pattern Maria pointed at (TryGhost/Actions) turns
   > out to be SHA pins bumped by Renovate with auto-merge for own-org actions — the same model as
   > here plus an unattended bumper, and Dependabot already plays that part (vite-plugin-shopify-clean
   > #95). A mutable ref is the only zero-commit mechanism (`uses:` resolves at run start), but across
   > v1.7.0–v1.14.0 seven of eight releases changed a whole-file kit file that carries no pin, so a
   > moving `@v1` on the three stubs would have removed one wave in eight; the per-repo commit is
   > `claude.yml`'s churn, which is this conversion's case. Its real costs: the `driver-digital-agents`
   > PAT holds admin here and lives in every client repo, so a moved tag's trust root is wider than the
   > wave's; the audit's pre-run convergence proof and the `--only` canary go; and `fleet-wave.sh`
   > guard 1, the audit's reference check, and `lint.yml`'s placeholder-pin guard all need rework
   > first. An npm package is the same mutability trade with a registry, a per-repo read token, and no
   > coverage from the org's `allowed_actions: selected` policy. Ruleset-required workflows are the one
   > true no-file mechanism and are Enterprise Cloud (DriverDigital is on Team); they fit only
   > `dependabot-validate`, whose move would break the `workflow_run` name-match to `-report`.

---

## Provenance

Researched 2026-07-31 by five parallel agents across: the OIDC/App-token path, event and gate semantics, the
`workflow_call` interface, `bonsai-status-sync` specifics, and migration risk. Every hard-blocker claim was
then put to an adversarial challenge agent instructed to refute it; **all six were refuted**. Doc claims are
sourced to official GitHub Actions docs, `anthropics/claude-code-action` source at the pinned SHA
`be7b93b1907a4abad570368f3c74b6fe3807510b`, issue #443, and this repo's own files.

**Refreshed 2026-08-02** against `main` @ `a54c91e` (v1.9.0) and re-verified the same day against the v1.11.0
release branch; every in-repo `file:line` citation was re-read and every arithmetic claim recomputed, and
citations became path-qualified. Five findings from the CodeRabbit review of PR #21 were adopted and one
**rejected on evidence** — see *On declaring secrets* above.

**Re-verified 2026-08-22 at `v1.13.0`.** Citations moved with the v1.13.0 rewrite of `claude.yml` (500 lines);
the `bonsai-status-sync` sections were removed with the rail. The research update near the top is dated
2026-08-22 and cites claude-code-action #443 and PR #1417 — both **external** and, like the original external
citations at pinned SHA `be7b93b…`, read from the upstream repo rather than re-verified here.
