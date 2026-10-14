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
| [**driver-agents**](https://github.com/DriverDigital/driver-agents) (private) | The pipeline dispatcher, the Shopify admin-tool wrapper and the canonical Shopify instructions (the implementer clones its `main`), the read-only Figma and Bonsai MCP servers, the Macroscope Check Run agent prompts and the nightly audit publisher. |
| [**driver-engineering-app**](https://github.com/DriverDigital/driver-engineering-app) (private) | The "Driver Engineering" Shopify app installed in each client org. Its client id and secret are the credentials the implementer's store tooling mints Admin API tokens from, and its app home shows clients what the agents did. |

How a ticket becomes a merged change:

1. A Bonsai task assigned to **Agents** and set to *Ready for Dev / Design* enters the pipeline.
2. The **dispatcher** (driver-agents `pipeline-dispatch.yml`, hourly) triages it, picks the repo (and,
   on Palmers, the branch) from driver-agents' project-repo map, opens a GitHub issue as `driver-digital-agents` with
   `@claude` in the body, and moves the task to *In Progress*. Anything it cannot route goes to a
   person with a `⚠️ Needs a human:` comment.
3. The repo's **`claude.yml`** (the implementer) branches `issue-<n>` from the issue's
   `Target branch:` line, else the repo's default branch, implements, pre-reviews its own diff with `/code-review`, and opens a PR whose
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

### Macroscope on a PR

- Its bot is `macroscopeapp[bot]`. It posts two non-blocking check runs (Approvability and
  Correctness), an approvability verdict comment, and one review carrying its inline findings.
- The verdict comment is edited in place as the PR changes, so read its current body. It reads
  `Approved at <sha>` once nothing is left.
- It resolves its own threads when a push addresses them.
- Approval follows risk, not file type: a low-risk code change can get a formal `APPROVED`, while a
  behaviour-changing PR or a fleet-changing kit release gets "not approved" with zero findings. Read
  the verdict, not the diff, and gate any status mapping on the actor.
- It runs at most three automatic correctness reviews per PR. Later pushes get a skipped check reading
  "Maximum runs reached" with no findings, which looks like a clean pass. Post
  `@macroscope-app review this PR` to run one more on the current head.
- A spending-limit stall ("Monthly spending limit reached") looks identical to a refusal on the code.
  Tell the two apart before treating "not approved" as a verdict.
- Answer an accepted residual once in its thread, with the decision, and leave it.

## What's here

| Reusable (`.github/workflows/`) | Privilege | Caller trigger | Job |
|---|---|---|---|
| `claude.yml` | OAuth token, PAT, optional store, alert and Figma secrets; write token | `issues` opened, `issue_comment` created, `pull_request_review` submitted, `pull_request_review_comment` created | The implementer. An `@claude`'d issue becomes a dev-linked branch and a PR; `@claude` on a PR runs tag mode on its branch. |
| `dependabot-validate.yml` | **none** (credential-less) | `pull_request` | Install, build, test (plus optional theme check and dev smoke) and npm registry facts → an inert artifact. Non-Dependabot PRs pass green. |
| `dependabot-report.yml` | PAT + OAuth token | `workflow_run` on `Dependabot validate` | Reads the artifact, posts a verdict comment and requests a human reviewer. |
| `dependabot-keep-current.yml` | PAT (its token is read-only) | `pull_request` closed | After a merge, asks Dependabot to rebase its PRs on that base that conflict, or that fell behind on a branch requiring up-to-date merges. Inert otherwise. |
| `shopify-theme.yml` | theme token; read-only GitHub token | `pull_request` to and `push` on `main` / `main-*` | Shopify sites: an unpublished preview theme `DRIVER/<branch>` per PR and per release branch. The build runs in a job with no secrets. |
| `vercel-deploy.yml` | the main deploy hook | `push` on `main` | Vercel sites: fires the main deploy hook when the pusher is outside the Vercel team. The build is staged; production is a promotion in Vercel. |

The kit — every stub, whole-file workflow and standards file, where each goes and how to install it —
is documented in [`templates/github/README.md`](templates/github/README.md).

Two files in `.github/workflows/` are **this repo's own CI** and never ship:

- `lint.yml` (job `actionlint`, the required check on `main`): actionlint and shellcheck over the
  reusables and the kit, the placeholder-pin guard, the `claude_args` tokenization and `prompt:` brace
  checks, the Shopify blockquote against driver-agents `main` (on PRs), and a schema check of
  the `dependabot/` variants. It is a different file from the kit's `templates/github/lint.yml`, which
  lints only the installing repo's own workflows; both use the job id `actionlint`.
- `dependabot-auto-merge.yml`: auto-merges this repo's `github-owned` Dependabot bumps.
  `claude-code-action` majors land by hand.

`main` here requires `actionlint`, up-to-date branches and one approval, with `enforce_admins: false`: release commits are
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
  `tools/kit-platforms.sh` picks. On Shopify repos with `claude.yml` it also writes the check-run
  agents to `.macroscope/check-run-agents/`, read from driver-agents `main`. It never adds a
  platform stub; that arrives with the repo's canary or cutover commit.
- **Dependabot is the backstop.** Each `dependabot.yml` variant carries a `github-actions` block, so
  Dependabot also bumps the stub pins on a repo the wave skipped. It scans the default branch only.
- **The audit proves convergence.** `tools/fleet-pin-audit.sh` compares every deployed pin and kit
  file against the latest tag and `templates/`, and exits non-zero on any drift.
- **Partial installs are normal.** A repo off the ticket pipeline can carry just `lint.yml` and the
  standards (driver-engineering-app does). driver-agents carries no `claude.yml` or
  `pr-bonsai-link.yml` (it is off the ticket pipeline) and no `dependabot-report` (its
  `secrets: inherit` would hand a shared workflow the Bonsai key); the wave only refreshes what a
  repo carries, so it never adds them.

Install steps, the required checks and the multi-branch (Palmers) setup:
[`templates/github/README.md`](templates/github/README.md). Wave mechanics and what the
audit cannot see: [`docs/fleet-operations.md`](docs/fleet-operations.md).

## Release + repin order

Do the steps in order. A wave is safe only once all three are done.

1. **Merge to `main`, cut the tag and push it.** The wave reads the tag locally and the audit reads it
   from GitHub, so an unpushed tag waves clean and then audits as stale everywhere.
2. **Repin every stub in `templates/github/`** to the tag's SHA and its `# vX.Y.Z` trailer in one sed,
   then commit. A reusable added in this release gets its stub here: its tag is cut in step 1, so it
   cannot be pinned earlier. `lint.yml` fails on a placeholder pin and `fleet-wave.sh` refuses an
   unrepinned kit, so this step cannot be skipped silently.
3. **Wave, then audit.** `tools/fleet-wave.sh --dry-run`, then for real: one direct `[skip ci]` commit
   per branch. Then `tools/fleet-pin-audit.sh --stale` must report converged.

The wave writes every kit file whole from `templates/`, stubs included, so a deployed stub ends up
byte-identical to the kit whatever SHA it held before. It never patches a file in place; the one merge is `.claude/settings.json`, where it writes only the
kit's `attribution` keys.

**A kit-only change needs no tag and no wave.** If no reusable changed and no pin moved, nothing
deployed has to move, and the change rides with the next release. Cutting a tag is what creates the
obligation to wave, because the audit compares every stub against the latest tag. The audit also
compares each deployed kit file against `templates/`, so between a kit-only merge and the next wave
it reports content drift on the changed files; that is expected and clears with the wave. The
check-run agents are compared with driver-agents `main` instead, so a change merged there reads as
drift until a wave from `main` with `--message` carries it; no tag is needed.

## Action refs

Nothing bumps a pin inside `templates/` (Dependabot scans only `.github/workflows/`), while a fleet
repo's Dependabot bumps its deployed copy. So the reusables and the kit's whole-file workflows
reference third-party actions by **major tag** (`actions/checkout@v7`,
`anthropics/claude-code-action@v1`): each run resolves the latest minor and patch, and the only action
bump that ever gets a PR is a new major. When one ships, bump the kit's major to match.

Two refs stay manual: the `DriverDigital/workflows` stub pins (the wave) and the actionlint
`VERSION` + `SHA256` pair in `lint.yml`, which move together. driver-agents is read at `main`.

## Identities and secrets

- **`claude[bot]`** (the Claude GitHub App, installed org-wide) implements: it authors branches,
  commits and PRs.
- **`driver-digital-agents`** (`AGENTS_GH_PAT`) dispatches: it authors the dispatcher's issues and
  revise-loop `@claude` comments, `dependabot-report`'s verdict and reviewer request, and
  `dependabot-keep-current`'s rebase requests. The implementer uses it only in its store-provisioning step, to clone driver-agents and read the
  issue for the audit's ticket context; `shopify-tool-smoke.yml` uses it for the same clone.
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

Which exact context to require, with up-to-date branches and a human approver: kit README, install step 5.
