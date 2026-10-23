# GitHub pipeline kit

The kit a DriverDigital repo with the `driver-kit` topic takes, as far as its tier allows (central
README, *How a repo takes the kit*): the house standards and lint, the Dependabot config and stubs,
each platform's CI/CD stub, and on pipeline repos the workflows that connect it to the Bonsai → PR
pipeline. The pipeline dispatcher (in
`driver-agents`) opens a GitHub **issue** from a ready Bonsai task and `@claude`s it; these workflows
take it from there. The dispatcher owns every Bonsai status move; no workflow here touches Bonsai.

### Whole files (installed verbatim per repo, except `claude-settings.json`, whose keys are merged)

| File | Goes to | Does |
|---|---|---|
| `pr-bonsai-link.yml` | `.github/workflows/pr-bonsai-link.yml` — private repos | Checks the Bonsai link in a PR body. A PR body that never mentions `hellobonsai.com` is skipped (grey, never red). The PR template mentions it, so a templated PR reads red until its `Bonsai task:` line is filled in. One that mentions it must carry an `app.hellobonsai.com/tasks/<uuid>` URL, a board link ending `task=<uuid>`, or `Bonsai task: none`. Check-run context is the job id, **`bonsai-link`**. |
| `close-linked-issues.yml` | `.github/workflows/close-linked-issues.yml` — every kit repo | On a PR merged into a `main-*` branch (Palmers' country branches), closes the open issues its body names with a closing keyword (`Closes #N`), which GitHub honours only on the default branch. Not a required check. |
| `pull_request_template.md` | `.github/pull_request_template.md` — private repos | Gives human PRs the `Bonsai task: <url> \| none` line `bonsai-link` checks for, and prompts them to **link the Bonsai issue** (`Closes #N`) so the dispatcher can resolve the task. AI PRs write both themselves. |
| `claude-standards.md` | `.github/claude-standards.md` — every kit repo | The house standards: commits, comments, to-dos, `docs/HANDOFF.md`, docs shipping with the change, branches and PRs, comments on a PR, closing issues, theme editor changes on a preview, `ponytail:` comments, subagents, replies. The repo's `CLAUDE.md` imports it with `@.github/claude-standards.md` (replacing any pasted copy). On a PR run the import resolves to the PR head's copy, so it carries style only. |
| `claude-settings.json` | `.claude/settings.json` — every kit repo | Shared Claude Code project settings: turns off the commit `Co-Authored-By` trailer and the PR "Generated with" footer in interactive sessions (CI sets the same keys). The kit owns only its `attribution` keys: the wave merges them into a repo's existing file and the audit compares only them, so the repo keeps the rest. |
| `shopify-tool-smoke.yml` | `.github/workflows/` — Shopify repos with a store, on the agents pipeline | Manual (`workflow_dispatch`) diagnostic for the Shopify admin tool: secrets → `driver-agents` clone of `main` → token mint → Admin API, read-only. Fails **loudly** where `claude.yml` degrades — that's the point. |
| `dependabot/<variant>.yml` | `.github/dependabot.yml` — every kit repo | The Dependabot config, one whole file per kind of repo: `npm.yml` (a root `package.json`), `actions.yml` (no root `package.json`; every kit repo has workflows once waved), and one per repo with its own exceptions (`driver-agents.yml`, `vite-plugin-shopify-clean.yml`). `tools/kit-platforms.sh` picks the variant; a new exception becomes a variant, not a hand edit. Its `github-actions` block is also the updater for the stub pins, which nothing else bumps between waves. |
| `node-version/<platform>` | `.node-version` at the repo root — wave targets with a platform topic | The Node major for that platform (`24`), so a Node move is one kit edit and a wave from `main` with `--message`, with no release. The reusables read it before `.nvmrc` and `package.json`; developers get it through mise once driver-onboarding#41 lands. Vercel builds on `package.json` `engines.node` and ignores this file, so a Vercel repo keeps `engines.node` at the same major (`24.x`); the audit flags a mismatch. |
| `lint.yml` | `.github/workflows/lint.yml` — every kit repo | actionlint + shellcheck over the installing repo's own `.github/workflows/`. Guards the one CI failure with no signal: a YAML or shell error surfaces as a `startup_failure` — no check run, no notification — which on the PR page is indistinguishable from checks that have not started. Check-run context is the job id, **`actionlint`**. Not the same file as the central repo's own `.github/workflows/lint.yml`, which runs a superset and never ships. |

### Caller stubs (thin — they call the central reusables at a pinned SHA)

All go to `.github/workflows/` unchanged; the two platform stubs are below. Each pins
`DriverDigital/workflows/...@<sha>`; the trailing `# vX.Y.Z` comment on the `uses:` line is the only
place the version is recorded.

| File | Rail |
|---|---|
| `claude.yml` | The implementer, on private repos with the `agents-pipeline` topic; the reusable fails the run on a public repo. On an `@claude`'d issue it creates a **development-linked branch** `issue-<n>` from the issue's `Target branch:` (else the default branch), honours an "Instructions from the ticket" section, implements, pre-reviews its own diff with the built-in `/code-review`, and opens a **real PR** whose body carries `Closes #n`, a `Bonsai task:` line, a `How to QA` section when the issue states acceptance criteria, and a `Pre-review:` line. The model requests no reviewer. The dispatcher requests the ticket's reviewer at hand-off; on an issue with no Bonsai task the workflow requests its author. Either is requested only when driver-agents `pipeline/reviewers.json` lists them, and the no-ticket path falls back to `PR_REVIEWER_HANDLE`. `@claude` on a PR (standalone comment, review, or inline comment) runs tag mode on its branch. Issue runs carry no attribution trailer on commits and no PR footer; a human's tag-mode `@claude` can add a `Co-authored-by` naming that person. The stub holds the triggers, a coarse `@claude` filter, the concurrency group, the permissions and `secrets: inherit`; the actor gate and everything else are in the reusable. |
| `dependabot-validate.yml` | Credential-less install/build/test → uploads an inert artifact. Carries **no `secrets:` line** — deliberate, do not add one. |
| `dependabot-report.yml` | Private repos. Reasons over that artifact → verdict comment + human reviewer request. Passes the reusable its two secrets by name, never `inherit`, so a repo's own credentials stay out of a job that reads Dependabot output. |
| `dependabot-keep-current.yml` | Private repos. After a merge, asks Dependabot to rebase its PRs on that base that conflict, or that fell behind on a branch requiring up-to-date merges. Inert otherwise. |

### Platform stubs (one platform each)

A repo takes the kit only with the `driver-kit` topic, and these only when it is private. Its
platform topic, `shopify-theme`, `vercel-site` or `wordpress-site` (no platform files), decides
which of these it may carry; the wave never writes one to a public repo or to a repo of another
platform or of none (`tools/kit-platforms.sh`). The wave refreshes a platform stub only where a repo
already carries it; the first copy comes from the repo's canary or cutover commit. The standards and the cutover steps:
[`../../docs/branch-model.md`](../../docs/branch-model.md).

| File | Platform | Rail |
|---|---|---|
| `shopify-theme.yml` | Shopify | PR preview theme `DRIVER/<branch>` (pushed on open and every push, draft or ready, linked at the end of the PR description, deleted on close; none for a PR that changes only `.github/`, `.claude/`, `docs/` or Markdown files) and `DRIVER/<branch>` on push to `main` / `main-*`; the build runs in a job with no secrets, and a live theme is never touched. |
| `shopify-tool-smoke.yml` | Shopify (store repos) | A whole file, not a stub; see the whole-files table. |
| `vercel-deploy.yml` | Vercel | Fires the main deploy hook on push to `main` when the pusher is not in `VERCEL_TEAM_LOGINS`. The build is a staged production deployment; production is a promotion in Vercel. |

**PR review is Macroscope's job, not the kit's.** Macroscope reviews every PR in the DriverDigital org,
and the dispatcher's revise loop answers its findings. Claude reviews a PR only when a person
`@claude`s it (optionally naming `/code-review`); the implementer's own `/code-review` pass before it
opens a PR is part of implementing. A repo outside the org gets no automatic review. How Macroscope
behaves on a PR: [`../../README.md`](../../README.md#macroscope-on-a-pr).

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

People own Revisions Requested and every status after Internal Review on the board (Paused, Ready
for QA, Client Review, Ready For Deployment, Info Needed, Delivered / Deployed / Completed), and
every merge.

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
     requests, the implementer's `driver-agents` clone on store repos, and its reviewer request on
     an issue with no Bonsai task. A few `claude.yml` steps
     use the default token on purpose (central `README.md`, *Identities and secrets*).
   - `FIGMA_MCP_SECRET` — the bearer for driver-agents' Figma MCP server, which the implementer
     reads design files through (`../../docs/figma-mcp-in-ci.md`).
   - `SHOPIFY_ALERT_WEBHOOK` — destructive, failed or refused store-tool calls alert to
     `#driver-agents-status` through it, labeled with the run URL. If it is ever absent, alerts are
     silently off and nothing else changes.

   Optional, per-repo:
   - **variable** `PR_REVIEWER_HANDLE` to override the reviewer requested by the
     Dependabot-report rail and by the implementer on an issue with no Bonsai task (default
     `mcarter-astronautdev`).
   - **Shopify admin tooling** — only for repos with a store. Set all three secrets
     `DRIVER_ENGINEERING_APP_CLIENT_ID`, `DRIVER_ENGINEERING_APP_CLIENT_SECRET`, `SHOPIFY_STORE` (the
     myshopify domain) **and** the repository **variable** `SHOPIFY_STORE_NAME` to the store handle.
     Leave the variable unset and the provisioning step self-skips cleanly.
     The handle must be a plain `[A-Za-z0-9_-]` string — it becomes a filename, and anything else
     fails the step loudly. Even on a store repo the step skips the read-only `/code-review` rail,
     so a review run never holds the app's long-lived credentials; and `driver-agents` is cloned from
     `main`, with the tool's presence checked before any credential is written to disk.
     The implementer's system prompt carries the Shopify operator tripwire (never bypass the
     wrapper; never evade an exit-3 refusal) — the blockquote is copied verbatim from driver-agents
     `docs/agent-instructions-shopify.md`, which is canonical: edit there first, then re-copy into
     the reusable (`../../.github/workflows/claude.yml`; the central `lint.yml` fails PRs until they
     match) and release, **preserving the scope lead-in that precedes it** (it is not canonical
     text — it un-scopes the block from the conduct and quality-standard blocks above and tells the
     model how to report a trip on a rail with no exit code; see the comment in the reusable). The
     whole value rides inside a **single-quoted** CLI token: **no apostrophes anywhere in it** — one
     apostrophe silently truncates the prompt instead of erroring. The central repo's `lint.yml` asserts the quote count.
3. **Issue creation:** the pipeline dispatcher (driver-agents, a scheduled Actions workflow)
   opens issues as the driver-digital-agents PAT, which is what lets `claude.yml` fire on
   `issues: [opened]` (the default GITHUB_TOKEN cannot retrigger workflows). The PAT is
   fine-grained across **All repositories**, and its minimal permission set, not the repo list, is
   the security boundary: it reads and writes issues and PRs and reads code and Actions (artifacts, run logs), and can never push code.
4. **Set the topics, then let the wave install the kit.** The topics are `driver-kit`, the repo's
   platform if it has one, and `agents-pipeline` if it is private and takes Bonsai tickets; the wave
   touches nothing on a repo without `driver-kit`, and refuses a public repo with `agents-pipeline`.
   Then run `tools/fleet-wave.sh --only <repo>` from a clean `main` (`--dry-run` first): it adds
   every file the repo's tier allows (central README, *How a repo takes the kit*), including
   `.github/dependabot.yml` from the variant that fits the repo (table above) with the Dependabot
   stubs, and the root `.node-version` from its platform's file. A platform's stubs and
   `shopify-tool-smoke.yml` come from its canary or cutover commit (`../../docs/branch-model.md`),
   since they need the repo's secrets first. Then add `@.github/claude-standards.md` to the repo's
   `CLAUDE.md` (a new repo: start `CLAUDE.md` as that line and let `/init` write the rest around it),
   the one step the wave cannot do. For a repo the wave cannot reach, copy the files by hand:
   ```bash
   mkdir -p .github/workflows .claude
   # every kit repo
   cp templates/github/lint.yml                 .github/workflows/
   cp templates/github/close-linked-issues.yml  .github/workflows/
   cp templates/github/dependabot-validate.yml  .github/workflows/
   cp templates/github/dependabot/<variant>.yml .github/dependabot.yml  # npm, actions, or the repo's own
   cp templates/github/node-version/<platform>  .node-version            # platform repos only
   cp templates/github/claude-standards.md      .github/claude-standards.md
   cp templates/github/claude-settings.json     .claude/settings.json  # existing file: merge its attribution keys
   # private repos
   cp templates/github/dependabot-report.yml    .github/workflows/
   cp templates/github/dependabot-keep-current.yml .github/workflows/
   cp templates/github/pr-bonsai-link.yml       .github/workflows/
   cp templates/github/pull_request_template.md .github/pull_request_template.md
   # private repos with agents-pipeline
   cp templates/github/claude.yml               .github/workflows/
   ```
   The wave covers Palmers' country branches the same way ([fleet operations](../../docs/fleet-operations.md#dependabot-and-the-wave)
   on what Dependabot updates there). It copies whole files, since no kit file carries a per-repo
   value, except `.claude/settings.json`, where only the kit's `attribution` keys are merged in. It
   refuses a repo whose deployed file carries a store handle the `SHOPIFY_STORE_NAME` variable
   does not hold — set the variable first.
   **And check for an existing `.github/workflows/lint.yml`** — a repo that hand-rolled its own would
   be silently clobbered by the kit's; it is the one kit *workflow* name likely to already exist.
5. **Pin the required check.** Run a test PR (one human, one Dependabot), then pin the **exact
   check context GitHub reports**. Copy the literal string from the first run's checks list; the
   workflow display **name** is never part of it. Turn on **require branches to be up to date
   before merging** at the same time: every repo requires it, and it applies only against required checks.
   Two shapes:
   - A **reusable-workflow** job reports `<caller-job-id> / <reusable-job-id>` — for the full kit
     that is **`validate / validate`** (`dependabot-validate`).
   - A **local** job reports its bare job id — `lint.yml` reports **`actionlint`**, `pr-bonsai-link.yml`
     **`bonsai-link`**.
     Before requiring `bonsai-link` on a private repo, check that fork PRs are either disabled or
     allowed to run workflows — a fork PR that never runs it waits on "Expected" forever.

   Until the wave gives a repo `dependabot-validate`, `actionlint` is the one check that runs on
   every PR unconditionally, so it is the right thing to require — but **run it once and let it go
   green before you pin it**. `lint.yml` lints every workflow the repo already has, not just the
   ones this kit ships, so a repo with its own hand-written workflows can have findings to fix on
   day one. (`actionlint` fails on *info*-level shellcheck findings too. The kit excludes
   `SC2015`, which the runner's shellcheck reports and current shellcheck does not; add
   further exclusions to `SHELLCHECK_OPTS` in that repo's copy if it needs them.)

   Never require a context whose workflow's trigger list can leave a head SHA with **no run at
   all** (e.g. a `pull_request` list without `synchronize`) — a required context with no check run
   is **missing**, not skipped, and blocks the merge indefinitely. (A job that *runs* and reports
   `skipped` is a different case; GitHub accepts that — reason from whether a check run exists for
   the head commit, not from the word "skipped".) Also add a rule requiring a **human** approver
   (e.g. CODEOWNERS) so no bot signal satisfies the merge gate.

6. **Route tickets to it.** Once the repo carries `agents-pipeline` and `claude.yml` is live on the
   default branch, add the client's Bonsai
   project to driver-agents `pipeline/project-repo-map.json` with its `repo` and
   `"pipeline": "github"`. Only a Palmers entry names a `branch`. Until then the dispatcher opens no
   issues there.

## Multi-branch repos (e.g. Palmers — independent release branches)

Some repos run **several independent long-lived branches that merely share one repo** — Palmers runs
one per country store (`main` = Palmers USA, plus `main-ca`, `main-in`, `main-me`, `main-sa`, and
`main-au` / `main-uk` / `main-ma`), and foundrae-blackridge runs `main-development` for its
development store. These branches are *not* a hub-and-spoke off `main`; they don't intersect. Treat
each branch as its own self-contained store. On a repo whose default branch is `main`, the wave and
the pin audit cover every `main-*` branch.

- **Install `claude.yml` on EVERY release branch.** Because the branches are independent, each one
  carries its own copy of the kit. (Strictly, the issue/`@claude` *kickoff* always fires from the
  repo's default branch — that's a hard GitHub rule for `issues` events; installing it on every
  branch means no one has to reason about which event resolves from where.)
- **The map decides the branch.** Branch routing lives in driver-agents
  `pipeline/project-repo-map.json`: each Palmers project carries an explicit `branch` (e.g. the
  Palmers India project → `main-in`, the Palmers USA / Managed-Services project → `main`). The
  dispatcher writes a `**Target branch:**` line into the issue body, and the implementer bases its
  dev-linked branch on it (`gh issue develop --base <branch>`) and opens the PR into it. A Repo
  directive in the ticket can override the map's repo, but only for a repo that has `claude.yml`.
  On a repo with several entries, the client identifies the branch (a Palmers Morocco ticket is
  `main-ma`) and the dispatcher resolves it to the map entry's branch. A `branch:` line on the ticket
  is optional.
- **`Closes #n` on a merge into `main-*`.** GitHub closes linked issues only on merges into the
  default branch, so the kit's `close-linked-issues.yml` closes them on a `main-*` merge. Each issue
  needs its own keyword (`Closes #1, closes #2`), as on the default branch.
- **Don't flag a project whose branch doesn't exist yet.** A `branch` must be a real branch in the
  repo before the project is `"pipeline": "github"` — otherwise the implementer can't branch from it.

## Validate before trusting it

Let the dispatcher open one real issue, then confirm the chain forms — the issue gains a
**development-linked branch** and a **real `pull_request` `opened` event authored by `claude[bot]`**
appears in the Actions log, and the task reaches **Internal Review** — not merely that "a PR exists"
(a human clicking Claude's prefilled PR link would false-pass). If you see only a prefill link and
no `pull_request` event, the implementer didn't drive the flow.
