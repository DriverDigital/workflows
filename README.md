# DriverDigital/workflows — central reusable workflows

> **Staging note:** this directory is staged inside `driver-bonsai-mcp` for review. Its contents are the
> source for the **`DriverDigital/workflows`** repo — the single source for the Bonsai→GitHub pipeline's
> reusable workflows. Until those files are pushed there + a `v1.0.0` is tagged, the caller stubs in
> `driver-bonsai-mcp/templates/github/*.yml` pin to a placeholder SHA (`@0000…0000`).

## Go-live (one-time)

1. Create `DriverDigital/workflows` (done) and push `.github/workflows/*` + `config/reviewers.json` + this
   `README.md` to its default branch.
2. **Tag that commit `v1.0.0`** (`git tag v1.0.0 && git push origin v1.0.0`, or a GitHub Release) and copy its
   **commit SHA**. The tag is just a human label + Renovate's bump target; the caller stubs pin the immutable
   **SHA**, so paste that SHA over the `@0000…0000` placeholder in each of the three `templates/github/*.yml`
   stubs. Also SHA-pin the in-reusable `actions/*` + `claude-code-action` refs at this point.
3. `AGENTS_GH_PAT` + `CLAUDE_CODE_OAUTH_TOKEN` are already org Actions secrets, and cross-repo Actions access is
   enabled — no secret setup needed.
4. Install the three stubs into the pilot repo's `.github/workflows/`, run a test PR (human + Dependabot), then
   pin the required check `validate / validate` + add a human-approver rule.

## What's here (Phase 3 — PR-first rail)

| Reusable (`.github/workflows/`) | Privilege | Trigger (in the caller) | Job |
|---|---|---|---|
| `pr-first-review.yml` | secrets (PAT + OAuth) | `pull_request` | human no-ticket PR → `/code-review` (comments) + request a human reviewer |
| `dependabot-validate.yml` | **none** (credential-less) | `pull_request` | mechanical install/build/test (+ optional theme/dev-smoke) → upload artifact |
| `dependabot-report.yml` | secrets (PAT + OAuth) | `workflow_run` | reason over the **inert** artifact → verdict comment + request a human reviewer |

Phase 4 migrates the Phase-2 kit (`claude.yml`, `bonsai-status-sync.yml`) into this same repo as reusables.

## The three identities

- **`claude[bot]`** — the implementer (Phase 2 `claude.yml`), distinct from the reviewer.
- **`driver-digital-agents`** (the `AGENTS_GH_PAT` fine-grained PAT) — the reviewer/PR-first actor. Passed as
  `claude-code-action`'s `github_token` and as `GH_TOKEN` on every `gh` step (never the default
  `GITHUB_TOKEN`).
- **Anthropic billing** — `CLAUDE_CODE_OAUTH_TOKEN` (Max). **Never set `anthropic_api_key`** (it overrides
  OAuth and bills at API rates).

Both secrets must be **org-level Actions secrets** available to each consuming repo.

## The Dependabot security split (load-bearing)

`dependabot-validate` runs untrusted Dependabot code (install + PR-modifiable build) but holds **no
secrets** — three independent layers: Dependabot forces a read-only token + no Actions secrets; the caller
stub passes no `secrets:`; this reusable declares no `workflow_call.secrets`. `dependabot-report` holds the
secrets but **never checks out PR head and never runs PR code** — its agent reads ONLY the inert artifact
(`build.log`/`result.json`, never interpolated into a `run:` line) with a read/write-file-only tool surface
(no `gh`), after a **provenance assertion** (event `pull_request`, actor `dependabot[bot]`, non-empty PR
number, same-repo head). **Never use `pull_request_target`.**

## Consuming it (caller stubs)

Install the matching stubs from `driver-bonsai-mcp/templates/github/` into a repo's `.github/workflows/`.
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
PR-first rail does **not** read `reviewers.json` at runtime — it only needs the default/override. The bundled
`config/reviewers.json` (full Bonsai-name → handle map) is the canonical input for the **ticketed rail**
(future), which resolves the reviewer from the Bonsai Reviewer field.

## First-run / required-check

The `dependabot-validate` job **always runs and branches internally** (non-Dependabot PRs no-op green) — a
*skipped* required check counts as not-passed and would block every human PR, so it must never be `if:`-skipped.
After the first run on a test PR: pin the **exact required-check context GitHub reports** — for a
reusable-workflow job it is `<caller-job-id> / <reusable-job-id>`, expected **`validate / validate`** (the
workflow display name is NOT part of the context; copy the literal string from the first run's checks list).
Then confirm the `claude[bot]` author literal + `gh --create-if-none` on the runner. Require a **human**
approver (e.g. CODEOWNERS) so no bot signal
satisfies the merge gate.
