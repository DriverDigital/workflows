# DriverDigital/workflows — central reusable workflows

Single source for Driver's Bonsai→GitHub pipeline reusable workflows **and the onboarding kit**
(`templates/github/` in this repo). Each consuming repo installs a thin caller stub per workflow that pins
an **immutable commit SHA**; a bot (Dependabot/Renovate) bumps the SHAs as new tags ship. This repo is
**public** so cross-repo reusable calls resolve from any consuming repo (the org enforces a
selected-actions allowlist at the org/enterprise tier).

## How the three repos fit together

- **workflows** (this repo, public) — the reusable GitHub workflows + this onboarding kit. Fleet
  repos carry thin SHA-pinned caller stubs; these run the GitHub side (implementer, reviews, Bonsai
  status sync) once an issue exists.
- **[driver-bonsai-mcp](https://github.com/DriverDigital/driver-bonsai-mcp)** — the Bonsai bridge
  server (MCP + REST) *and* the Bonsai job pack (`pipeline/`) that defines the triage/executor cron
  jobs which open those issues.
- **[driver-agents](https://github.com/DriverDigital/driver-agents)** (private) — the generic
  headless `claude -p` cron runner the production box uses to execute the job pack.

Flow: a Bonsai ticket assigned to **Agents** → the box cron (driver-agents runner + the job pack +
the bridge server) triages it and opens a GitHub issue → the target repo's caller stubs + these
reusables implement, review, and sync status back to Bonsai.

## Status & versions

Latest tag **`v1.5.5`** (`0b1a657`) — **five** reusables. The onboarding kit in `templates/github/` pins
all five caller stubs @ **v1.5.5** (`0b1a657`); deployed fleet stubs are repinned by **manual waves** —
Dependabot does NOT bump these reusable-workflow pins in practice (zero such PRs fleet-wide; debugging
why is on the backlog). Audit drift any time with `tools/fleet-pin-audit.sh`. Org Actions secrets (`AGENTS_GH_PAT`, `CLAUDE_CODE_OAUTH_TOKEN`,
`BONSAI_BEARER_TOKEN`) and cross-repo Actions access are already in place — no per-repo secret setup.
Tags are human labels + the bot's bump target; the caller stubs pin the SHA. History: `v1.0.0` (initial
rail) → `v1.0.1` (no-ticket detection fix) → `v1.0.2` (`dependabot-report` bot-actor fix) → `v1.1.0` (add
`dependabot-keep-current` + claude-code-action bump) → `v1.1.1` (keep-current fail-loud fix) → `v1.2.0`
(PR-first house-style review) → `v1.4.0` (PR-first outcome-aware marker) → `v1.5.2` (add the
`ticketed-review` reviewer-loop rail) → `v1.5.3` (always-latest resilient Claude Code self-install in the
three agent reusables) → `v1.5.4` (`dependabot-validate`: npm-install fallback for lockfile-less repos +
`actions/checkout` v7) → `v1.5.5` (claude-code-action 1.0.161 → 1.0.168 in the agent reusables).

**Onboarding a new repo:** copy the matching stubs from **this repo's `templates/github/`** into the
repo's `.github/workflows/`, run a test PR (human + Dependabot), then pin the required check
`validate / validate` + add a human-approver rule (see *First-run / required-check* below). Caller stubs
MUST carry their own `permissions:` block (a repo whose default workflow token is read-only otherwise
produces a silent `startup_failure` — no check run, no notification).

## What's here

| Reusable (`.github/workflows/`) | Privilege | Trigger (in the caller) | Job |
|---|---|---|---|
| `pr-first-review.yml` | secrets (PAT + OAuth) | `pull_request` | human no-ticket PR → `/code-review` (comments) + request a human reviewer |
| `ticketed-review.yml` | secrets (PAT + OAuth + Bonsai) | `pull_request` + `issue_comment` | claude[bot] **ticketed** PR → capped `/code-review` revise loop (max 3 passes) → hand off to a human (Bonsai reassign via the server's `/tasks/reviewer-handoff`) |
| `dependabot-validate.yml` | **none** (credential-less) | `pull_request` | mechanical install/build/test (+ optional theme/dev-smoke) → upload artifact |
| `dependabot-report.yml` | secrets (PAT + OAuth) | `workflow_run` | reason over the **inert** artifact → verdict comment + request a human reviewer |
| `dependabot-keep-current.yml` | PAT only | `pull_request` (closed) | rebase out-of-date Dependabot PRs on **strict** (require-up-to-date) repos; inert elsewhere |

**The onboarding kit lives here: `templates/github/`** (moved from `driver-bonsai-mcp` 2026-07-15). It
carries the five caller stubs above plus the two full per-repo workflows — `claude.yml` (the implementer)
and `bonsai-status-sync.yml` (deterministic status flips) — and `pull_request_template.md`. Converting
those two full workflows into reusables remains future work; until then they are installed per-repo
verbatim.

## The three identities

- **`claude[bot]`** — the implementer (Phase 2 `claude.yml`), distinct from the reviewer.
- **`driver-digital-agents`** (the `AGENTS_GH_PAT` fine-grained PAT) — the reviewer/PR-first actor. Passed as
  `claude-code-action`'s `github_token` and as `GH_TOKEN` on every `gh` step (never the default
  `GITHUB_TOKEN`).
- **Anthropic billing** — `CLAUDE_CODE_OAUTH_TOKEN` (Max). **Never set `anthropic_api_key`** (it overrides
  OAuth and bills at API rates).

All three secrets must be **org-level Actions secrets** available to each consuming repo.

## The Dependabot security split (load-bearing)

`dependabot-validate` runs untrusted Dependabot code (install + PR-modifiable build) but holds **no
secrets** — three independent layers: Dependabot forces a read-only token + no Actions secrets; the caller
stub passes no `secrets:`; this reusable declares no `workflow_call.secrets`. `dependabot-report` holds the
secrets but **never checks out PR head and never runs PR code** — its agent reads ONLY the inert artifact
(`build.log`/`result.json`, never interpolated into a `run:` line) with a read/write-file-only tool surface
(no `gh`), after a **provenance assertion** (event `pull_request`, actor `dependabot[bot]`, non-empty PR
number, same-repo head). **Never use `pull_request_target`.**

## Consuming it (caller stubs)

Install the matching stubs from **this repo's `templates/github/`** into a repo's `.github/workflows/`.
Pin every `uses:` to an **immutable commit SHA** (decided 2026-06-17); a bot (Renovate/Dependabot) bumps the
SHAs. The `dependabot-validate` stub's `name:` MUST stay byte-identical (`Dependabot validate`) across all
repos — the `dependabot-report` stub's `workflow_run` trigger name-matches it exactly, and a drift silently
disables the human-ping.

### Per-repo validation override (target repo: `.github/agent-validate.json`)

```json
{
  "install": "npm ci",
  "build": "npm run build",
  "test": "npm test",
  "themeCheck": "npx @shopify/cli theme check --fail-level error",
  "dev": "npm run dev",
  "devTimeoutSeconds": 90,
  "devReadyRegex": "compiled|ready|built in|Local:"
}
```

All keys optional. Defaults: package manager from the lockfile (**npm** is the house default), `build`/`test`
run only if those `package.json` scripts exist, `themeCheck`/`dev` run only if configured.

## Reviewer handoff

Both rails request a human GitHub reviewer = the reusable's `default-reviewer-handle` input (default
`mcarter-astronautdev` = Maria), overridable per-repo via the `PR_REVIEWER_HANDLE` Actions **variable**. The
PR-first rail does **not** read `reviewers.json` at runtime — it only needs the default/override. The full
Bonsai-name → handle map (`config/reviewers.json` in `driver-bonsai-mcp`, build-copied into the server's
`dist/`) is consumed by the **ticketed rail**: its `/tasks/reviewer-handoff` server endpoint (LIVE since
2026-06-26) resolves the Bonsai Reviewer field → a GitHub handle (default Maria) and reassigns the Bonsai
task. The `config/reviewers.json` copy in **this** repo is reference only — no workflow reads it at runtime.

## First-run / required-check

The `dependabot-validate` job **always runs and branches internally** (non-Dependabot PRs no-op green) — a
*skipped* required check counts as not-passed and would block every human PR, so it must never be `if:`-skipped.
After the first run on a test PR: pin the **exact required-check context GitHub reports** — for a
reusable-workflow job it is `<caller-job-id> / <reusable-job-id>`, expected **`validate / validate`** (the
workflow display name is NOT part of the context; copy the literal string from the first run's checks list).
Then confirm the `claude[bot]` author literal + `gh --create-if-none` on the runner. Require a **human**
approver (e.g. CODEOWNERS) so no bot signal
satisfies the merge gate.
