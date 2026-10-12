# DriverDigital/workflows

The GitHub side of Driver's agentic pipeline. Two products live here:

- **Reusable workflows** in `.github/workflows/` (`workflow_call` only): the implementer that turns a
  ticket into a pull request, the three Dependabot rails, and one CI/CD rail per hosting platform.
- **The onboarding kit** in [`templates/github/`](templates/github/README.md): the caller stubs and
  whole-file workflows a client repo installs, plus the house standards every repo's `CLAUDE.md`
  imports.

Each fleet repo carries thin caller stubs that pin a reusable here by **immutable commit SHA**.
`tools/fleet-wave.sh` repins them after each release and keeps every kit file current;
`tools/fleet-pin-audit.sh` reports drift. The repo is **public** so a cross-repo `uses:` resolves from
any client repo (the org allows only selected actions).

State of play, open decisions and next steps: [`docs/HANDOFF.md`](docs/HANDOFF.md). The agent-facing
subset of these conventions: [`CLAUDE.md`](CLAUDE.md).

## Where it sits in the pipeline

| Repo | Role |
|---|---|
| **workflows** (this repo, public) | The GitHub rails every fleet repo runs: the implementer, Dependabot, platform deploys. |
| [**driver-agents**](https://github.com/DriverDigital/driver-agents) (private) | The pipeline dispatcher, the Shopify admin-tool wrapper and the canonical Shopify instructions (cloned by the implementer at the pinned `DRIVER_AGENTS_REF`), the read-only Figma and Bonsai MCP servers, the Macroscope Check Run agent prompts and the nightly audit publisher. |
| [**driver-engineering-app**](https://github.com/DriverDigital/driver-engineering-app) (private) | The "Driver Engineering" Shopify app installed in each client org. Its client id and secret are the credentials the implementer's store tooling mints Admin API tokens from, and its app home shows clients what the agents did. |

How a ticket becomes a merged change:

1. A Bonsai task assigned to **Agents** and set to *Ready for Dev / Design* enters the pipeline.
2. The **dispatcher** (driver-agents `pipeline-dispatch.yml`, hourly) triages it, picks the repo and
   branch from driver-agents' project-repo map, opens a GitHub issue as `driver-digital-agents` with
   `@claude` in the body, and moves the task to *In Progress*. Anything it cannot route goes to a
   person with a `⚠️ Needs a human:` comment.
3. The repo's **`claude.yml`** (the implementer) branches `issue-<n>` from the issue's
   `Target branch:`, implements, pre-reviews its own diff with `/code-review`, and opens a PR whose
   body carries `Closes #n`, `Bonsai task: <url>` and a `Pre-review:` line.
4. **Macroscope** reviews every PR in the org. It is the only automatic reviewer; Claude reviews a PR
   only when a person `@claude`s it.
5. The dispatcher runs the **revise loop**: while Macroscope has unresolved findings it posts a
   tag-mode `@claude` on the PR, up to three turns, and hands anything still flagged to a person.
6. The dispatcher moves the task to **Internal Review** and assigns it to the reviewer the ticket
   names. That Bonsai assignment is the review request; nothing is requested on GitHub.
7. A reviewer who sets **Revisions Requested** and assigns the task to Agents gets their comments
   forwarded to the PR as `@claude`; the task returns to Internal Review after the push. People own
   merging and every status after Internal Review.

The flow end to end, and Macroscope's behaviour on a PR:
[`docs/macroscope-integration-scope.md`](docs/macroscope-integration-scope.md).

## What's here

| Reusable (`.github/workflows/`) | Privilege | Caller trigger | Job |
|---|---|---|---|
| `claude.yml` | OAuth token, PAT, optional store, alert and Figma secrets; write token | `issues` opened, `issue_comment` created, `pull_request_review` submitted, `pull_request_review_comment` created | The implementer. An `@claude`'d issue becomes a dev-linked branch and a PR; `@claude` on a PR runs tag mode on its branch. |
| `dependabot-validate.yml` | **none** (credential-less) | `pull_request` | Install, build, test (plus optional theme check and dev smoke) and npm registry facts → an inert artifact. Non-Dependabot PRs pass green. |
| `dependabot-report.yml` | PAT + OAuth token | `workflow_run` on `Dependabot validate` | Reads the artifact, posts a verdict comment and requests a human reviewer. |
| `dependabot-keep-current.yml` | PAT (its token is read-only) | `pull_request` closed | After a merge, asks Dependabot to rebase its PRs on that base that conflict, or that fell behind on a branch requiring up-to-date merges. Inert otherwise. |
| `shopify-theme.yml` | theme token; read-only GitHub token | `pull_request` to and `push` on `main` / `main-*` | Shopify sites: an unpublished preview theme `DRIVER/<branch>` per PR and per release branch. The build runs in a job with no secrets. |
| `vercel-deploy.yml` | the two deploy hooks | `push` on `main` / `develop` | Vercel sites: fires the branch's deploy hook when the pusher is outside the Vercel team. |

The kit — every stub, whole-file workflow and standards file, where each goes and how to install it —
is documented in [`templates/github/README.md`](templates/github/README.md).

Two files in `.github/workflows/` are **this repo's own CI** and never ship:

- `lint.yml` (job `actionlint`, the required check on `main`): actionlint and shellcheck over the
  reusables and the kit, the placeholder-pin guard, the `claude_args` tokenization and `prompt:` brace
  checks, `DRIVER_AGENTS_REF` parity with `shopify-tool-smoke.yml`, and a schema check of the
  `dependabot/` variants. It is a different file from the kit's `templates/github/lint.yml`, which
  lints only the installing repo's own workflows; both use the job id `actionlint`.
- `dependabot-auto-merge.yml`: auto-merges this repo's `github-owned` Dependabot bumps.
  `claude-code-action` majors land by hand.

`main` here requires `actionlint` and one approval, with `enforce_admins: false`: release commits are
pushed directly. Branch protection details: [`docs/fleet-operations.md`](docs/fleet-operations.md#branch-protection).

## How a repo takes the kit

- **Topics decide everything.** `driver-kit` enrolls a repo; the wave touches nothing without it. A
  platform topic (`shopify-theme`, `vercel-site`, `wordpress-site`) decides which platform files it may
  carry, and a repo with two platform topics blocks the wave. The lists live in
  `tools/kit-platforms.sh`; the standards and the per-repo cutover in
  [`docs/branch-model.md`](docs/branch-model.md).
- **Stubs pin by SHA.** Every `uses: DriverDigital/workflows/...@<sha> # vX.Y.Z` names the release in
  its trailer. The pin and the trailer are one value and always move together.
- **The wave keeps it current.** `tools/fleet-wave.sh` replaces each kit file a target branch already
  carries, installs `pr-bonsai-link.yml`, `claude-standards.md` and the `.claude/settings.json`
  attribution keys wherever `claude.yml` is, and writes `.github/dependabot.yml` from the variant
  `tools/kit-platforms.sh` picks. It never adds a platform stub; that arrives with the repo's cutover or
  install commit.
- **Dependabot is the backstop.** Each `dependabot.yml` variant carries a `github-actions` block, so
  Dependabot also bumps the stub pins on a repo the wave skipped. It scans the default branch only.
- **The audit proves convergence.** `tools/fleet-pin-audit.sh` compares every deployed pin and kit
  file against the latest tag and `templates/`, and exits non-zero on any drift.
- **Partial installs are normal.** A repo off the ticket pipeline can carry just `lint.yml` and the
  standards (driver-engineering-app does). driver-agents carries no `claude.yml`, `dependabot-report`
  or `pr-bonsai-link.yml`, because its repo secrets must never reach a shared workflow; the wave only
  refreshes what a repo carries, so it never adds them.

Install steps, the required checks and the multi-branch (Palmers) setup:
[`templates/github/README.md`](templates/github/README.md). Wave mechanics, fleet counts and what the
audit cannot see: [`docs/fleet-operations.md`](docs/fleet-operations.md).

## Release + repin order

Do the steps in order. A wave is safe only once all three are done.

1. **Merge to `main`, cut the tag and push it.** The wave reads the tag locally and the audit reads it
   from GitHub, so an unpushed tag waves clean and then audits as stale everywhere.
   - **If `DRIVER_AGENTS_REF` moved**, run the blockquote parity check first. Extract the `>` lines
     from driver-agents `docs/agent-instructions-shopify.md` at the new pin, strip the `> ` prefixes,
     NFC-normalize, **collapse whitespace**, and diff against the blockquote in the reusable
     `claude.yml`'s `--append-system-prompt`. The collapse is required because the copy flattens one
     paragraph break. Nothing else checks this: `lint.yml` proves only that the reusable and
     `shopify-tool-smoke.yml` carry the same ref.
2. **Repin every stub in `templates/github/`** to the tag's SHA and its `# vX.Y.Z` trailer in one sed,
   then commit. A reusable added in this release gets its stub here: its tag is cut in step 1, so it
   cannot be pinned earlier. `lint.yml` fails on a placeholder pin and `fleet-wave.sh` refuses an
   unrepinned kit, so this step cannot be skipped silently.
3. **Wave, then audit.** `tools/fleet-wave.sh --dry-run`, then for real: one direct `[skip ci]` commit
   per branch. Then `tools/fleet-pin-audit.sh --stale` must report converged.

The wave writes every kit file whole from `templates/`, stubs included, so a deployed stub ends up
byte-identical to the kit whatever SHA it held before. It never patches a file in place.

**A kit-only change needs no tag and no wave.** If no reusable changed and no pin moved, nothing
deployed has to move, and the change rides with the next release. Cutting a tag is what creates the
obligation to wave, because the audit compares every stub against the latest tag. The audit also
compares each deployed kit file against `templates/`, so between a kit-only merge and the next wave
it reports content drift on the changed files; that is expected and clears with the wave.

## Action refs

Nothing bumps a pin inside `templates/` (Dependabot scans only `.github/workflows/`), while a fleet
repo's Dependabot bumps its deployed copy. So the reusables and the kit's whole-file workflows
reference third-party actions by **major tag** (`actions/checkout@v7`,
`anthropics/claude-code-action@v1`): each run resolves the latest minor and patch, and the only action
bump that ever gets a PR is a new major. When one ships, bump the kit's major to match.

Three refs stay manual: the `DriverDigital/workflows` stub pins (the wave), `DRIVER_AGENTS_REF` (a raw
SHA in `env:`, identical in the reusable `claude.yml` and `shopify-tool-smoke.yml`), and the actionlint
`VERSION` + `SHA256` pair in `lint.yml`, which move together.

## Identities and secrets

- **`claude[bot]`** (the Claude GitHub App, installed org-wide) implements: it authors branches,
  commits and PRs.
- **`driver-digital-agents`** (`AGENTS_GH_PAT`) dispatches: it authors the dispatcher's issues and
  revise-loop `@claude` comments, `dependabot-report`'s verdict and reviewer request, and
  `dependabot-keep-current`'s rebase requests. The implementer uses it only to clone driver-agents.
  The implementer's actor gate keys on this split, so keep the two apart.
- **The default `GITHUB_TOKEN`** is used where a post must not trigger another run and where the PAT
  is not needed: `claude.yml`'s trusted-authors check, its no-PR check and its failed-run notice, and
  this repo's `dependabot-auto-merge.yml`.

Org-level Actions secrets, visible to every repo, so a new repo needs no secret setup:
`CLAUDE_CODE_OAUTH_TOKEN` (subscription billing), `AGENTS_GH_PAT`, `FIGMA_MCP_SECRET`,
`SHOPIFY_ALERT_WEBHOOK` and `BONSAI_API_KEY` (the dispatcher's). Store repos add their own store
secrets and the `SHOPIFY_STORE_NAME` variable (kit README, install step 2). **Never set
`anthropic_api_key`**: it overrides the OAuth token and bills at API rates.

## The Dependabot security split

`dependabot-validate` runs untrusted Dependabot code (install and a PR-modifiable build) and holds **no
secrets**, by three independent layers: Dependabot forces a read-only token and no Actions secrets, the
stub passes no `secrets:`, and the reusable declares none.

`dependabot-report` holds the secrets and **never checks out or runs PR code**. It first asserts
provenance (event `pull_request`, actor `dependabot[bot]`, a PR number, a same-repo head, and a
validate run that succeeded or failed rather than cancelled), then its agent reads only the inert
artifact (`build.log`, `result.json`, `registry.json`) with `Read`, `Glob`, `Grep` and `Write` and no
`gh`. Artifact content is never interpolated into a `run:` line. **Never use `pull_request_target`.**

The validate stub's `name:` stays byte-identical (`Dependabot validate`) in every repo, because
`dependabot-report`'s `workflow_run` trigger matches it by name and a drift silently stops the reviewer
request. The reviewer is `mcarter-astronautdev` unless the repo sets the `PR_REVIEWER_HANDLE` variable.

### Per-repo validation override (`.github/agent-validate.json`)

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

All keys are optional. Node comes from `.nvmrc`, else `package.json` (`volta.node`, then
`engines.node`), else the runner's default. The package manager comes from the lockfile (`pnpm`,
`yarn`, else npm, the house default). `build` and `test` run only if those `package.json` scripts
exist unless the override sets them; `themeCheck` and `dev` run only if configured.

## Required checks

The `dependabot-validate` job **always runs and branches internally**; never `if:`-skip it. A caller
job skipped by `if:` never starts the reusable, so the nested `validate / validate` context is never
created, and a required context with no check run for the head commit blocks the merge forever.
GitHub does accept a check run that concludes `skipped`; what matters is whether a check run exists for
the head SHA.

After the first run on a test PR, require the **exact context GitHub reports**: a reusable job reports
`<caller-job-id> / <reusable-job-id>` (`validate / validate`), and the workflow's display name is never
part of it. Also require a **human** approver (e.g. CODEOWNERS), so no bot signal satisfies the merge
gate. Which checks a partial install should require: kit README, install step 5.
