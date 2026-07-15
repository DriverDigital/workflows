# GitHub pipeline kit (Phase 2)

Drop-in workflows that connect a DriverDigital repo to the Bonsai → PR pipeline. The cron
orchestrator (on the box) opens a GitHub **issue** from a ready Bonsai task and `@claude`s it;
these workflows take it from there and keep the Bonsai task's status in lockstep with the PR
lifecycle.

| File | Goes to | Does |
|---|---|---|
| `claude.yml` | `.github/workflows/claude.yml` | The implementer — claude-code-action reads an `@claude`'d issue, creates a **development-linked branch** from it, writes code, and opens a **real PR** from that branch; it addresses revisions when `@claude`'d on the PR (standalone comment, review, or inline comment). |
| `bonsai-status-sync.yml` | `.github/workflows/bonsai-status-sync.yml` | Deterministic (no-agent) Bonsai status flips on issue/PR events; on a PR it resolves the **linked issue** (`closingIssuesReferences`) and reads the task URL from the **issue** body — never from the PR body. |
| `pull_request_template.md` | `.github/pull_request_template.md` | Prompts human PRs to **link the Bonsai issue** (`Closes #N`) so the sync can resolve the task. AI PRs link automatically via the issue's development branch. |

## Status machine

| Trigger | Bonsai status |
|---|---|
| Issue opened (`@claude`) | **In Progress** |
| PR opened / marked ready / new commits pushed | **Internal Review** |
| PR review requests changes | **Revisions Requested** |
| PR review **approved** | **Ready for QA** |

The pipeline **stops at Ready for QA** — a PM manually moves the task through Client Review →
Ready to Deploy → Delivered / Deployed / Completed. The workflows never set those.

## Install into a repo (one-time)

1. **Install the Claude GitHub App** on the repo — `/install-github-app` from the Claude Code
   CLI, or install `github.com/apps/claude` manually. The App identity is what opens/pushes PRs.
2. **Secrets** (repo or org → Settings → Secrets and variables → Actions):
   - `CLAUDE_CODE_OAUTH_TOKEN` — output of `claude setup-token` run as the **Agents** account
     (subscription billing). Keep any `ANTHROPIC_API_KEY` secret OUT of these repos — it would
     override the OAuth token and bill at API rates.
   - `BONSAI_BEARER_TOKEN` — must **byte-match** the server's `BEARER_TOKEN` (else every status
     flip 401s).
   - *(optional)* repo **variable** `BONSAI_URL` if the tunnel host ever changes (defaults to
     `https://driver-bonsai-mcp.ngrok.app`).
3. **Orchestrator PAT (the cascade requirement).** GitHub does **not** re-trigger workflows from
   events caused by the default `GITHUB_TOKEN`. The cron orchestrator must create issues with a
   **single fine-grained PAT owned by the `driver-digital-agents` machine-user account** —
   **All repositories**, permissions **Issues: R/W + Pull requests: R/W + Metadata: R** (no
   Contents/Admin, so no code-push) — stored on the box at `~/.secrets/gh-token`. Without it,
   issues are created but neither `claude.yml` nor the In-Progress flip fires. (claude-code-action
   opens/pushes PRs as the Claude App, so the PR events cascade on their own.) The minimal
   permission set is the security boundary, not the repo list — see `docs/phase2-github-setup.md`.
4. **Copy the kit:**
   ```bash
   mkdir -p .github/workflows
   cp templates/github/claude.yml            .github/workflows/
   cp templates/github/bonsai-status-sync.yml .github/workflows/
   cp templates/github/pull_request_template.md .github/pull_request_template.md
   ```
5. **Confirm the board strings.** `bonsai-status-sync.yml` hardcodes the exact Bonsai status
   strings. If the board is ever renamed, update them here — a miss fails the workflow loudly
   with `STATUS_NOT_FOUND` rather than flipping silently.

## Multi-branch repos (e.g. Palmers — independent release branches)

Some repos run **several independent long-lived branches that merely share one repo** — Palmers runs
one per country store (`main` = Palmers USA, plus `main-ca`, `main-in`, `main-me`, `main-sa`, and
`main-au` / `main-uk`; `main-ma` for Morocco is planned). These branches are *not* a hub-and-spoke off
`main`; they don't intersect. Treat each branch as its own self-contained store.

- **Install BOTH `claude.yml` and `bonsai-status-sync.yml` on EVERY release branch.** Because the
  branches are independent, each one carries its own copy of the kit. (Strictly, the issue/`@claude`
  *kickoff* always fires from the repo's default branch — that's a hard GitHub rule for `issues`
  events — and `pull_request` flips fire from the PR's target branch; installing both files on every
  branch covers all of it without having to reason about which event resolves from where.)
- **Which branch a task targets is decided by the map, not the task.** Branch routing lives in
  `config/project-repo-map.json`: each pipeline project carries an explicit `branch` (e.g. the Palmers
  India project → `main-in`, the Palmers USA / Managed-Services project → `main`). The orchestrator
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

- **Status sync alone first:** open a throwaway **issue** whose body carries a known task's full
  Bonsai URL, create a development-linked branch from it (`gh issue develop <issue> --checkout`),
  push a commit, open a PR from that branch, mark it ready for review, and confirm the task flips to
  **Internal Review**. Request changes → **Revisions Requested**; approve → **Ready for QA**. (A
  human PR that just says `Closes #<issue>` resolves identically.)
- **Then the full loop:** let the orchestrator open one real issue, then confirm the chain forms —
  the issue gains a **development-linked branch** and a **real `pull_request` `opened` event authored
  by `claude[bot]`** appears in the Actions log and flips the task to **Internal Review** — not
  merely that "a PR exists" (a human clicking Claude's prefilled PR link would false-pass). If you
  see only a prefill link and no `pull_request` event, the implementer didn't drive the flow — see
  `docs/phase2-github-setup.md` step 5. Then walk it to Ready for QA.

## Operational dependency

Every status flip hits the single Chrome on the box through the MCP mutex via the ngrok tunnel.
If the box is down or the Bonsai session lapses, status flips (AI **and** human) stop landing —
the `curl --retry` rides out a transient `503 BROWSER_BUSY`, but a sustained outage drops the
flip (the Actions step goes red). Monitor `/health` (`sessionValid`) — see the health-monitoring
crons in the main repo.
