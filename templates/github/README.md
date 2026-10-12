# GitHub pipeline kit

Drop-in workflows that connect a DriverDigital repo to the Bonsai → PR pipeline, plus each platform's
CI/CD stub, the Dependabot config and the house standards. The pipeline dispatcher (in
`driver-agents`) opens a GitHub **issue** from a ready Bonsai task and `@claude`s it; these workflows
take it from there. The dispatcher owns every Bonsai status move; no workflow here touches Bonsai.

### Whole files (installed verbatim per repo, except `claude-settings.json`, whose keys are merged)

| File | Goes to | Does |
|---|---|---|
| `pr-bonsai-link.yml` | `.github/workflows/pr-bonsai-link.yml` — wherever `claude.yml` is | Checks the Bonsai link in a PR body. A PR that never mentions `hellobonsai.com` is skipped (grey, never red — most human PRs have no ticket); one that does must carry an `app.hellobonsai.com/tasks/<uuid>` URL, a board link ending `task=<uuid>`, or `Bonsai task: none`. Check-run context is the job id, **`bonsai-link`**. |
| `pull_request_template.md` | `.github/pull_request_template.md` | Gives human PRs the `Bonsai task: <url> \| none` line `bonsai-link` checks for, and prompts them to **link the Bonsai issue** (`Closes #N`) so the dispatcher can resolve the task. AI PRs write both themselves. |
| `claude-standards.md` | `.github/claude-standards.md` — wherever `claude.yml` is | The house standards: commits, comments, to-dos, branches and PRs, subagents, replies. The repo's `CLAUDE.md` imports it with `@.github/claude-standards.md` (replacing any pasted copy). On a PR run the import resolves to the PR head's copy, so it carries style only. Lint-only repos are wave targets through it. |
| `claude-settings.json` | `.claude/settings.json` — wherever `claude.yml` is | Shared Claude Code project settings: turns off the commit `Co-Authored-By` trailer and the PR "Generated with" footer in interactive sessions (CI sets the same keys). The kit owns only its `attribution` keys: the wave merges them into a repo's existing file and the audit compares only them, so the repo keeps the rest. |
| `shopify-tool-smoke.yml` | `.github/workflows/` — Shopify repos with a store | Manual (`workflow_dispatch`) diagnostic for the Shopify admin tool: secrets → `driver-agents` clone at the pin → token mint → Admin API, read-only. Fails **loudly** where `claude.yml` degrades — that's the point. |
| `dependabot/<variant>.yml` | `.github/dependabot.yml` — wave targets with a variant | The Dependabot config, one whole file per kind of repo: `npm.yml` (a root `package.json`), `actions.yml` (workflows but no root `package.json`), one per repo with its own exceptions (`driver-agents.yml`, `vite-plugin-shopify-clean.yml`), and none for a repo with neither. `tools/kit-platforms.sh` picks the variant; a new exception becomes a variant, not a hand edit. Its `github-actions` block is also the updater for the stub pins, which nothing else bumps between waves. |
| `lint.yml` | `.github/workflows/lint.yml` | actionlint + shellcheck over the installing repo's own `.github/workflows/`. Guards the one CI failure with no signal: a YAML or shell error surfaces as a `startup_failure` — no check run, no notification — which on the PR page is indistinguishable from checks that have not started. Check-run context is the job id, **`actionlint`**. Not the same file as the central repo's own `.github/workflows/lint.yml`, which runs a superset and never ships. |

### Caller stubs (thin — they call the central reusables at a pinned SHA)

All go to `.github/workflows/` unchanged; the two platform stubs are below. Each pins
`DriverDigital/workflows/...@<sha>`; the trailing `# vX.Y.Z` comment on the `uses:` line is the only
place the version is recorded.

| File | Rail |
|---|---|
| `claude.yml` | The implementer. On an `@claude`'d issue it creates a **development-linked branch** `issue-<n>` from the issue's `Target branch:` (else the default branch), honours an "Instructions from the ticket" section, implements, pre-reviews its own diff with the built-in `/code-review`, and opens a **real PR** whose body carries `Closes #n`, a `Bonsai task:` line and a `Pre-review:` line. It requests no GitHub reviewer: the Bonsai assignment is the review request. `@claude` on a PR (standalone comment, review, or inline comment) runs tag mode on its branch. Commits carry no attribution trailer and PR bodies no footer. The stub holds the triggers, a coarse `@claude` filter, the concurrency group, the permissions and `secrets: inherit`; the actor gate and everything else are in the reusable. |
| `dependabot-validate.yml` | Credential-less install/build/test → uploads an inert artifact. Carries **no `secrets:` line** — deliberate, do not add one. |
| `dependabot-report.yml` | Reasons over that artifact → verdict comment + human reviewer request. |
| `dependabot-keep-current.yml` | After a merge, asks Dependabot to rebase its PRs that fell behind or conflict on that base. |

### Platform stubs (one platform each)

A repo takes the kit only with the `driver-kit` topic. Its platform topic, `shopify-theme`,
`vercel-site` or `wordpress-site` (no platform files yet), decides which of these it may carry; the
wave never writes one to a repo of another platform or of none (`tools/kit-platforms.sh`). The wave
refreshes a platform stub only where a repo already carries it; the first copy comes from the repo's
cutover or install commit. The standards, the cutover and the install steps:
[`../../docs/branch-model.md`](../../docs/branch-model.md).

| File | Platform | Rail |
|---|---|---|
| `shopify-theme.yml` | Shopify | PR preview theme `DRIVER/<branch>` (checked while draft, pushed when ready, deleted on close) and `DRIVER/<branch>` on push to `main` / `main-*`; the build runs in a job with no secrets, and a live theme is never touched. |
| `shopify-tool-smoke.yml` | Shopify (store repos) | The full workflow described above. |
| `vercel-deploy.yml` | Vercel | Fires the branch's deploy hook on push to `main` (production) or `develop` (preview) when the pusher is not in `VERCEL_TEAM_LOGINS`. The wave and the audit reach a repo's default branch, `develop`; `main` takes kit changes at its next promotion. |

**PR review is Macroscope's job, not the kit's.** Macroscope reviews every PR in the DriverDigital org,
and the dispatcher's revise loop answers its findings. Claude reviews a PR only when a person
`@claude`s it (optionally naming `/code-review`); the implementer's own `/code-review` pass before it
opens a PR is part of implementing. A repo outside the org gets no automatic review. See
[`../../docs/macroscope-integration-scope.md`](../../docs/macroscope-integration-scope.md).

Three rules that fail **silently** if broken:

- The `dependabot-validate.yml` stub's `name:` must stay byte-identical (`Dependabot validate`)
  across every repo — `dependabot-report.yml`'s `workflow_run` trigger name-matches it exactly, and
  a drift disables the human-ping with no error.
- Every caller stub must keep its own `permissions:` block. A repo whose default workflow token is
  read-only otherwise produces a silent `startup_failure` — no check run, no notification.
- The `claude.yml` stub grants all five permissions and keeps `secrets: inherit`. Without
  `id-token: write` no App token mints; an explicit secrets map that forgets the org-level
  `SHOPIFY_ALERT_WEBHOOK` turns destructive-call alerts off on a green run.

## Bonsai statuses

The dispatcher derives each move from GitHub on its hourly run. No workflow in this kit touches Bonsai.

| Trigger | Bonsai status |
|---|---|
| Issue opened | **In Progress** |
| PR open and Macroscope's findings worked through (revise loop done) | **Internal Review**, assigned to the reviewer the ticket names |
| A person sets **Revisions Requested** and assigns the task to Agents | comments forwarded to the PR as `@claude`; back to **Internal Review** after the push |

People own Revisions Requested and every status after Internal Review (Ready for QA, Client Review,
Ready to Deploy, Delivered / Deployed / Completed), and every merge.

## Install into a repo (one-time)

1. **Claude GitHub App**: installed org-wide, so nothing to do per repo. Its identity is what opens
   and pushes PRs.
2. **Secrets** (repo or org → Settings → Secrets and variables → Actions). The core ones are
   **org-level** Actions secrets available to every repo — no per-repo setup:
   - `CLAUDE_CODE_OAUTH_TOKEN` — output of `claude setup-token` run as the **Agents** account
     (subscription billing). Keep any `ANTHROPIC_API_KEY` secret OUT of these repos — it would
     override the OAuth token and bill at API rates.
   - `AGENTS_GH_PAT` — the `driver-digital-agents` fine-grained PAT: `GH_TOKEN` for
     `dependabot-report`'s verdict comment and reviewer request, `dependabot-keep-current`'s rebase
     requests, and the implementer's `driver-agents` clone on store repos. A few `claude.yml` steps
     use the default token on purpose (central `README.md`, *Identities and secrets*).
   - `FIGMA_MCP_SECRET` — the bearer for driver-agents' Figma MCP server, which the implementer
     reads design files through (`../../docs/figma-mcp-in-ci.md`).
   - `SHOPIFY_ALERT_WEBHOOK` — destructive or failed store-tool calls alert to
     `#driver-agents-status` through it, labeled with the run URL. If it is ever absent, alerts are
     silently off and nothing else changes.

   Optional, per-repo:
   - **variable** `PR_REVIEWER_HANDLE` to override the reviewer requested by the
     Dependabot-report rail (default `mcarter-astronautdev`).
   - **Shopify admin tooling** — only for repos with a store. Set all three secrets
     `DRIVER_ENGINEERING_APP_CLIENT_ID`, `DRIVER_ENGINEERING_APP_CLIENT_SECRET`, `SHOPIFY_STORE` (the
     myshopify domain) **and** the repository **variable** `SHOPIFY_STORE_NAME` to the store handle.
     Leave the variable unset and the provisioning step self-skips cleanly.
     The handle must be a plain `[A-Za-z0-9._-]` string — it becomes a filename, and anything else
     fails the step loudly. Even on a store repo the step skips the read-only `/code-review` rail,
     so a review run never holds the app's long-lived credentials; and `driver-agents` is cloned at
     the pinned `DRIVER_AGENTS_REF`, with the checkout verified against that pin before any
     credential is written to disk.
     The implementer's system prompt carries the Shopify operator tripwire (never bypass the
     wrapper; never evade an exit-3 refusal) — the blockquote is copied verbatim from driver-agents
     `docs/agent-instructions-shopify.md`, which is canonical: edit there first, re-copy into the
     reusable (`../../.github/workflows/claude.yml`) at the next release, **preserving the scope
     lead-in that precedes it** (it is not canonical text — it un-scopes the block from the conduct
     rules above and tells the model how to report a trip on a rail with no exit code; see the
     comment in the reusable). The whole value rides inside a **single-quoted** CLI token: **no
     apostrophes anywhere in it** — one apostrophe silently truncates the prompt instead of
     erroring. The central repo's `lint.yml` asserts the quote count.
3. **Issue creation:** the pipeline dispatcher (driver-agents, a scheduled Actions workflow)
   opens issues as the driver-digital-agents PAT, which is what lets `claude.yml` fire on
   `issues: [opened]` (the default GITHUB_TOKEN cannot retrigger workflows). The PAT is
   fine-grained across **All repositories**, and its minimal permission set, not the repo list, is
   the security boundary: it can read and write issues and PRs and read code, never push it.
4. **Set the topics, then copy the kit** (from a checkout of `DriverDigital/workflows`). The topics
   are `driver-kit` plus the repo's platform; the wave touches nothing on a repo without `driver-kit`.
   ```bash
   mkdir -p .github/workflows
   cp templates/github/claude.yml               .github/workflows/
   cp templates/github/dependabot-validate.yml  .github/workflows/
   cp templates/github/dependabot-report.yml    .github/workflows/
   cp templates/github/dependabot-keep-current.yml .github/workflows/
   cp templates/github/lint.yml                 .github/workflows/
   cp templates/github/pr-bonsai-link.yml       .github/workflows/
   cp templates/github/pull_request_template.md .github/pull_request_template.md
   cp templates/github/claude-standards.md      .github/claude-standards.md
   mkdir -p .claude && cp templates/github/claude-settings.json .claude/settings.json  # existing file: merge its attribution keys
   ```
   Then add `@.github/claude-standards.md` to the repo's `CLAUDE.md` (a new repo: start `CLAUDE.md`
   as that line and let `/init` write the rest around it).
   Every file above is kept current by the wave afterwards (`tools/fleet-wave.sh`, presence-based:
   it replaces what a branch already carries, and installs `pr-bonsai-link.yml`, `claude-standards.md`
   and the `claude-settings.json` keys beside `claude.yml`; the `CLAUDE.md` import line is the one step
   it cannot do). A platform's stubs come from its cutover or install commit (`../../docs/branch-model.md`).
   The wave also writes `.github/dependabot.yml` from the variant that fits the repo (table above),
   skipping a repo with no variant; copy the variant by hand only for a repo the wave cannot reach
   yet. Palmers' country branches carry it too but get no Dependabot updates (Dependabot reads the
   default branch only).
   **Re-copying into a repo that already has the kit?** Let the wave do it
   (`tools/fleet-wave.sh --only <repo>`): whole-file, since no kit file carries a per-repo value, except
   `.claude/settings.json`, where only the kit's `attribution` keys are merged in. It
   refuses a repo whose deployed file still carries a store handle the `SHOPIFY_STORE_NAME` variable
   does not hold — set the variable first.
   **And check for an existing `.github/workflows/lint.yml`** — a repo that hand-rolled its own would
   be silently clobbered by the kit's; it is the one kit *workflow* name likely to already exist.

   **Partial install (`lint.yml`, plus the standards).** For a repo that is *not* on the Bonsai → PR
   pipeline — no dispatcher issues — `lint.yml` and `claude-standards.md` are the useful subset and
   the rest is inert weight. `driver-engineering-app` runs both; the wave finds a branch by either
   file. Add Dependabot stubs if and when such a repo turns Dependabot on. `driver-agents` carries
   `lint.yml`, the standards, `dependabot-validate.yml` and `dependabot-keep-current.yml`, and
   deliberately no `dependabot-report.yml`, `claude.yml` or `pr-bonsai-link.yml`: its repo secrets
   must never reach a shared workflow. The wave never adds them, since it only refreshes what a repo
   carries (and installs beside `claude.yml`, which it lacks).
5. **Pin the required check.** Run a test PR (one human, one Dependabot), then pin the **exact
   check context GitHub reports**. Copy the literal string from the first run's checks list; the
   workflow display **name** is never part of it. Two shapes:
   - A **reusable-workflow** job reports `<caller-job-id> / <reusable-job-id>` — for the full kit
     that is **`validate / validate`** (`dependabot-validate`).
   - A **local** job reports its bare job id — `lint.yml` reports **`actionlint`**, `pr-bonsai-link.yml`
     **`bonsai-link`**.
     Before requiring `bonsai-link` on a private repo, check that fork PRs are either disabled or
     allowed to run workflows — a fork PR that never runs it waits on "Expected" forever.

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
`main-au` / `main-uk` / `main-ma`). These branches are *not* a hub-and-spoke off
`main`; they don't intersect. Treat each branch as its own self-contained store.

- **Install `claude.yml` on EVERY release branch.** Because the branches are independent, each one
  carries its own copy of the kit. (Strictly, the issue/`@claude` *kickoff* always fires from the
  repo's default branch — that's a hard GitHub rule for `issues` events; installing it on every
  branch means no one has to reason about which event resolves from where.)
- **Which branch a task targets is decided by the map, not the task.** Branch routing lives in
  driver-agents `pipeline/project-repo-map.json`: each pipeline project carries an explicit `branch`
  (e.g. the Palmers India project → `main-in`, the Palmers USA / Managed-Services project → `main`).
  The dispatcher writes a `**Target branch:**` line into the issue body, and the implementer bases its
  dev-linked branch on it (`gh issue develop --base <branch>`) and opens the PR into it. A Repo
  directive in the ticket can override the map's repo, but only for a repo that has `claude.yml`; the
  branch still comes from the map (`main` for a repo with no entry).
- **Don't flag a project whose branch doesn't exist yet.** A `branch` must be a real branch in the
  repo before the project is `"pipeline": "github"` — otherwise the implementer can't branch from it.

## Validate before trusting it

Let the dispatcher open one real issue, then confirm the chain forms — the issue gains a
**development-linked branch** and a **real `pull_request` `opened` event authored by `claude[bot]`**
appears in the Actions log, and the task reaches **Internal Review** — not merely that "a PR exists"
(a human clicking Claude's prefilled PR link would false-pass). If you see only a prefill link and
no `pull_request` event, the implementer didn't drive the flow.
