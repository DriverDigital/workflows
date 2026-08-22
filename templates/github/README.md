# GitHub pipeline kit (Phase 2)

Drop-in workflows that connect a DriverDigital repo to the Bonsai → PR pipeline. The pipeline
dispatcher (in `driver-bonsai-mcp`) opens a GitHub **issue** from a ready Bonsai task and
`@claude`s it; these workflows take it from there. Bonsai status is polled by the dispatcher — no
workflow here touches it.

### Full workflows (installed verbatim, per-repo)

| File | Goes to | Does |
|---|---|---|
| `claude.yml` | `.github/workflows/claude.yml` | The implementer — claude-code-action reads an `@claude`'d issue, creates a **development-linked branch** from it, writes code, and opens a **real PR** from that branch; it addresses revisions when `@claude`'d on the PR (standalone comment, review, or inline comment). On an issue it pre-reviews its own branch with the built-in `/code-review` skill before opening the PR, requests the reviewer named by a **Reviewer:** line in the issue, and honours an "Instructions from the ticket" section. Commits carry no attribution trailer and PR bodies no footer (the action's settings input). |
| `pull_request_template.md` | `.github/pull_request_template.md` | Prompts human PRs to **link the Bonsai issue** (`Closes #N`) so the dispatcher can resolve the task. AI PRs link automatically via the issue's development branch. |
| `shopify-tool-smoke.yml` | `.github/workflows/` — **STORE REPOS ONLY** | Manual (`workflow_dispatch`) diagnostic for the Shopify admin tool: secrets → `driver-agents` clone at the pin → token mint → Admin API, read-only. Fails **loudly** where `claude.yml` degrades — that's the point. Skip it in repos with no store. |
| `lint.yml` | `.github/workflows/lint.yml` | actionlint + shellcheck over the installing repo's own `.github/workflows/`. Guards the one CI failure with no signal: a YAML or shell error surfaces as a `startup_failure` — no check run, no notification — which on the PR page is indistinguishable from checks that have not started. Check-run context is the job id, **`actionlint`**. Not the same file as this repo's own `.github/workflows/lint.yml`, which runs a superset and never ships. |

### Caller stubs (thin — they call this repo's reusables at a pinned SHA)

All three go to `.github/workflows/` unchanged. Each pins `DriverDigital/workflows/...@<sha>`; the
trailing `# vX.Y.Z` comment on the `uses:` line is the only place the version is recorded.

| File | Rail |
|---|---|
| `dependabot-validate.yml` | Credential-less install/build/test → uploads an inert artifact. Carries **no `secrets:` line** — deliberate, do not add one. |
| `dependabot-report.yml` | Reasons over that artifact → verdict comment + human reviewer request. |
| `dependabot-keep-current.yml` | Rebases out-of-date Dependabot PRs on strict (require-up-to-date) repos; inert elsewhere. |

**PR review is Macroscope's job, not the kit's** (decided 2026-08-08). The old review rails —
`pr-first-review.yml` and `ticketed-review.yml` — were retired at v1.12.0: stubs deleted here and
fleet-wide, reusables preserved caller-less in the central repo. See
[`../../docs/macroscope-integration-scope.md`](../../docs/macroscope-integration-scope.md).

Two rules that fail **silently** if broken:

- The `dependabot-validate.yml` stub's `name:` must stay byte-identical (`Dependabot validate`)
  across every repo — `dependabot-report.yml`'s `workflow_run` trigger name-matches it exactly, and
  a drift disables the human-ping with no error.
- Every caller stub must keep its own `permissions:` block. A repo whose default workflow token is
  read-only otherwise produces a silent `startup_failure` — no check run, no notification.

## Status machine

The dispatcher polls GitHub and writes these. No workflow in this kit touches Bonsai.

| Trigger | Bonsai status |
|---|---|
| Issue opened | **In Progress** |
| Non-draft PR development-linked to the issue | **Internal Review** |

The pipeline **stops at Internal Review** — everything after it (Revisions Requested, Ready for
QA, Client Review → Ready to Deploy → Delivered / Deployed / Completed) is moved by a PM, pending
the Macroscope→Bonsai integration. The review-driven flips (changes requested → Revisions
Requested, approved → Ready for QA) were retired with the review leg at v1.12.0.

## Install into a repo (one-time)

1. **Install the Claude GitHub App** on the repo — `/install-github-app` from the Claude Code
   CLI, or install `github.com/apps/claude` manually. The App identity is what opens/pushes PRs.
2. **Secrets** (repo or org → Settings → Secrets and variables → Actions). The two core ones are
   already **org-level** Actions secrets available to every consuming repo — no per-repo setup:
   - `CLAUDE_CODE_OAUTH_TOKEN` — output of `claude setup-token` run as the **Agents** account
     (subscription billing). Keep any `ANTHROPIC_API_KEY` secret OUT of these repos — it would
     override the OAuth token and bill at API rates.
   - `AGENTS_GH_PAT` — the `driver-digital-agents` fine-grained PAT. The `GH_TOKEN` on every `gh`
     step (never the default `GITHUB_TOKEN`): `dependabot-report`'s verdict comment + reviewer
     request, and `claude.yml`'s sentinel posts.

   Optional, per-repo:
   - **variable** `PR_REVIEWER_HANDLE` to override the reviewer requested by the
     Dependabot-report rail (default `mcarter-astronautdev`).
   - **Shopify admin tooling** — only for repos with a store. Set all three secrets
     `DRIVER_ENGINEERING_APP_CLIENT_ID`, `DRIVER_ENGINEERING_APP_CLIENT_SECRET`, `SHOPIFY_STORE` (the
     myshopify domain) **and** edit `SHOPIFY_STORE_NAME` in the repo's copy of `claude.yml` to the
     store handle. Leave `SHOPIFY_STORE_NAME` empty and the provisioning step self-skips cleanly.
     The handle must be a plain `[A-Za-z0-9._-]` string — it becomes a filename, and anything else
     fails the step loudly. Even on a store repo the step skips the read-only `/code-review` rail,
     so a review run never holds the app's long-lived credentials; and `driver-agents` is cloned at
     the pinned `DRIVER_AGENTS_REF`, with the checkout verified against that pin before any
     credential is written to disk. Destructive or failed tool calls alert to
     `#driver-agents-status` from CI too — the org-level `SHOPIFY_ALERT_WEBHOOK` secret (already
     set org-wide, nothing per repo) is provisioned to the runner and the alert is labeled with the
     run URL; if that secret is ever absent, alerts are silently off and nothing else changes.
     The implementer's system prompt carries the Shopify operator tripwire (never bypass the
     wrapper; never evade an exit-3 refusal) — the blockquote is copied verbatim from driver-agents
     `docs/agent-instructions-shopify.md`, which is canonical: edit there first, re-copy here on
     the next kit bump, **preserving the kit-side scope lead-in that precedes it** (it is not
     canonical text — it un-scopes the block from the conduct rules above and tells the model how to
     report a trip on a rail with no exit code; see the comment in `claude.yml`). The whole value
     rides inside a **single-quoted** CLI token: **no apostrophes anywhere in it** — one apostrophe
     silently truncates the prompt instead of erroring. `lint.yml` asserts the quote count.
3. **Issue creation:** the pipeline dispatcher (driver-bonsai-mcp, a scheduled Actions workflow)
   opens issues as the driver-digital-agents PAT, which is what lets `claude.yml` fire on
   `issues: [opened]` (the default GITHUB_TOKEN cannot retrigger workflows). Bonsai status is
   polled by the dispatcher — no per-repo workflow is involved. The PAT is fine-grained — **All
   repositories**, permissions **Issues: R/W + Pull requests: R/W + Metadata: R** (no
   Contents/Admin, so no code-push) — and that minimal permission set, not the repo list, is the
   security boundary.
4. **Copy the kit** (from a checkout of `DriverDigital/workflows`):
   ```bash
   mkdir -p .github/workflows
   cp templates/github/claude.yml               .github/workflows/
   cp templates/github/dependabot-validate.yml  .github/workflows/
   cp templates/github/dependabot-report.yml    .github/workflows/
   cp templates/github/dependabot-keep-current.yml .github/workflows/
   cp templates/github/lint.yml                 .github/workflows/
   cp templates/github/pull_request_template.md .github/pull_request_template.md
   cp templates/github/dependabot.yml           .github/dependabot.yml
   ```
   **`dependabot.yml` is the updater for the stub pins** — without it nothing ever bumps the
   `uses: DriverDigital/workflows/...@<sha>` lines between waves. A repo that already has a
   `dependabot.yml` keeps its npm block and adds the kit's `github-actions` entry to it. Dependabot
   scans the default branch only, so a repo carrying the kit on other branches (Palmers) needs one
   entry per branch with `target-branch:` set.
   **Re-copying into a repo that already has the kit?** Preserve that repo's own Dependabot action
   pins — re-copy the workflow bodies, but don't clobber pins Dependabot has since bumped there.
   **And check for an existing `.github/workflows/lint.yml`** — a repo that hand-rolled its own would
   be silently clobbered by the kit's, which is the only kit filename likely to already exist.

   **Partial install (`lint.yml` only).** For a repo that is *not* on the Bonsai → PR pipeline —
   no dispatcher issues — `lint.yml` is the useful subset and the rest is inert weight. This is
   what `driver-agents` and `driver-agents-app` run (their `pr-first-review.yml` was removed with
   the v1.12.0 retirement; Macroscope reviews their PRs like everyone else's). Add the Dependabot
   trio if and when such a repo turns Dependabot on.
5. **Pin the required check.** Run a test PR (one human, one Dependabot), then pin the **exact
   check context GitHub reports**. Copy the literal string from the first run's checks list; the
   workflow display **name** is never part of it. Two shapes:
   - A **reusable-workflow** job reports `<caller-job-id> / <reusable-job-id>` — for the full kit
     that is **`validate / validate`** (`dependabot-validate`).
   - A **local** job reports its bare job id — `lint.yml` reports **`actionlint`**.

   On a partial install with no `dependabot-validate`, `actionlint` is the one check that runs on
   every PR unconditionally, so it is the right thing to require — but **run it once and let it go
   green before you pin it**. `lint.yml` lints every workflow the repo already has, not just the
   ones this kit ships, so a repo with its own hand-written workflows can have findings to fix on
   day one. (`actionlint` fails on *info*-level shellcheck findings too. The kit already excludes
   `SC2015`, which the runner's older shellcheck still reports and upstream has since dropped; add
   further exclusions to `SHELLCHECK_OPTS` in that repo's copy if it needs them.)

   Never require a context whose workflow's trigger list can leave a head SHA with **no run at
   all** (e.g. a `pull_request` list without `synchronize`) — a required context with no check run
   is **missing**, not skipped, and blocks the merge indefinitely. (A job that *runs* and reports
   `skipped` is a different case; GitHub accepts that — reason from whether a check run exists for
   the head commit, not from the word "skipped".) Also add a rule requiring a **human** approver
   (e.g. CODEOWNERS) so no bot signal satisfies the merge gate.

## Multi-branch repos (e.g. Palmers — independent release branches)

Some repos run **several independent long-lived branches that merely share one repo** — Palmers runs
one per country store (`main` = Palmers USA, plus `main-ca`, `main-in`, `main-me`, `main-sa`, and
`main-au` / `main-uk`; `main-ma` for Morocco is planned). These branches are *not* a hub-and-spoke off
`main`; they don't intersect. Treat each branch as its own self-contained store.

- **Install `claude.yml` on EVERY release branch.** Because the branches are independent, each one
  carries its own copy of the kit. (Strictly, the issue/`@claude` *kickoff* always fires from the
  repo's default branch — that's a hard GitHub rule for `issues` events; installing it on every
  branch means no one has to reason about which event resolves from where.)
- **Which branch a task targets is decided by the map, not the task.** Branch routing lives in
  `config/project-repo-map.json`: each pipeline project carries an explicit `branch` (e.g. the Palmers
  India project → `main-in`, the Palmers USA / Managed-Services project → `main`). The dispatcher
  reads that `branch`, writes a `**Target branch:**` directive into the issue body, and the implementer
  bases its dev-linked branch on it (`gh issue develop --base <branch>`) and opens the PR into it. The
  task's *Github Repo* custom field is **not** consulted for routing of map-routed repos, so a task
  with a blank/stale field still routes correctly — **except** for cross-cutting repos on the map's
  `fieldRoutableRepos` allow-list, which ARE routed by the *Github Repo* field (overriding the project
  map); the branch is still taken from config, never the field.
- **Don't flag a project whose branch doesn't exist yet.** A `branch` must be a real branch in the
  repo before the project is `"pipeline": "github"` — otherwise the implementer can't branch from it.
  (Palmers Morocco is mapped to `main-ma` but left unflagged until that branch is created.)

## Validate before trusting it

Let the dispatcher open one real issue, then confirm the chain forms — the issue gains a
**development-linked branch** and a **real `pull_request` `opened` event authored by `claude[bot]`**
appears in the Actions log, and the task reaches **Internal Review** — not merely that "a PR exists"
(a human clicking Claude's prefilled PR link would false-pass). If you see only a prefill link and
no `pull_request` event, the implementer didn't drive the flow. Statuses past Internal Review are
moved by hand since v1.12.0, so Internal Review is where the automated part of the walk ends.
