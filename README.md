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

Latest tag **`v1.11.0`** (`90f0d06`, 2026-08-02) — **not** kit-only. It carries three things: the
`bonsai-status-sync.yml` **caller stub** (the reusable itself landed one tag earlier at `v1.10.0` =
`b394c6d`, so the conversion spans the two), the `DRIVER_AGENTS_REF` bump, and the Shopify operator
tripwire. The other five reusables have been byte-identical since `v1.6.0`'s `0a3934f`. All six stubs
are pinned to `90f0d06`.

**In `v1.11.0` — `DRIVER_AGENTS_REF` → `4d63371`, lockstep in `claude.yml` +
`shopify-tool-smoke.yml`.** The previous pin `0bbb125` predated the Admin API wrapper:
`graphql_guard.py` does not exist at that SHA, so every fleet runner executes `admin-graphql.sh`
with **no fail-closed allowlist** and the Driver Engineering scope grant is the only control on
destructive mutations. This is a `claude.yml` change, which stays a per-repo copy — so **no client
repo is guarded in CI until the next wave copies it out**. The same release appends the Shopify
**operator tripwire** to `claude.yml`'s static `--append-system-prompt` (the blockquote is copied from
driver-agents `docs/agent-instructions-shopify.md`, which is canonical — edit there first, and preserve
the kit-side scope lead-in that precedes it), so the fleet gets the wrapper and its instruction block in
one wave.

**Decided 2026-08-02: shipped as `v1.11.0` rather than folded into the v1.10.0 wave.** Folding it in
would have put `claude.yml` content on 18 branches that exists in no tag, and `tools/fleet-pin-audit.sh`
compared only stub pin lines against the latest tag — never `templates/` content — so it would have
reported the fleet uniform and green over the gap. (That blind spot is now closed: the audit also
checks `templates/` against the latest tag and every waved file against `templates/`.) Executed as: merge → tag `v1.11.0` at that merge
commit → repin all six stubs to `v1.11.0` → **one** wave. That is what `v1.7.0` and `v1.8.0` each did.

**Note on the pin sequence:** `v1.9.0` (`a54c91e`, the store-secret rename) never got its kit repin
commit — the kit's stubs sat at `v1.8.0`'s SHA through that release and jump straight to `v1.10.0`
here. Deployed fleet stubs were repinned to `v1.9.0` by the 2026-08-01 wave, so between then and this
tag the fleet was *ahead* of the kit templates. The v1.11.0 wave resolves both. Deployed fleet stubs are
repinned by **manual waves** — Dependabot does NOT bump these reusable-workflow pins in practice
(zero such PRs fleet-wide; debugging why is on the backlog). Org Actions secrets (`AGENTS_GH_PAT`,
`CLAUDE_CODE_OAUTH_TOKEN`, `BONSAI_BEARER_TOKEN`, `SHOPIFY_ALERT_WEBHOOK`) and cross-repo Actions
access are already in place — no per-repo secret setup.

Tags are human labels + the bot's bump target; the caller stubs pin the SHA. History: `v1.0.0` (initial
rail) → `v1.0.1` (no-ticket detection fix) → `v1.0.2` (`dependabot-report` bot-actor fix) → `v1.1.0` (add
`dependabot-keep-current` + claude-code-action bump) → `v1.1.1` (keep-current fail-loud fix) → `v1.2.0`
(PR-first house-style review) → `v1.3.1` (PR-first: REQUIRE the allow-list naming the inline-comment
poster) → `v1.4.0` (PR-first outcome-aware marker) → `v1.5.0` (add the `ticketed-review` reviewer-loop
rail) → `v1.5.1` (drop the `gh`-based author re-check that skipped every real PR) → `v1.5.2`
(`allowed_bots: claude[bot]`, so the bot-opened round 1 actually reviews) → `v1.5.3` (always-latest
resilient Claude Code self-install in the three agent reusables) → `v1.5.4` (`dependabot-validate`:
npm-install fallback for lockfile-less repos + `actions/checkout` v7) → `v1.5.5` (claude-code-action
1.0.161 → 1.0.168 in the agent reusables) → `v1.6.0` → `v1.7.0` → `v1.8.0` → `v1.9.0` → `v1.10.0` →
**`v1.11.0`** (all below). `v1.3.0` was never tagged.

### `v1.11.0` (`90f0d06`, 2026-08-02)

Waved to all 21 repin targets on 2026-08-02; fleet uniform, 108 pins, zero stale.

- **`bonsai-status-sync.yml` conversion completed.** The 190-line per-repo copy became a 67-line
  caller stub — the status machine, actor gate, linkage logic and cascade caveat now live in one
  central file. The reusable itself landed one tag earlier (see `v1.10.0`), so the conversion spans
  the two tags: a new reusable's stub cannot be pinned until the tag containing it exists.
- **kit `claude.yml` + `shopify-tool-smoke.yml`:** `DRIVER_AGENTS_REF` → `4d63371`. The previous pin
  `0bbb125` predated `graphql_guard.py`, so every fleet runner executed `admin-graphql.sh` with no
  fail-closed allowlist and the Driver Engineering scope grant was the only control on destructive
  mutations.
- **Shopify operator tripwire** appended to `claude.yml`'s static `--append-system-prompt`, pairing
  with that wrapper. The blockquote is copied verbatim from driver-agents
  `docs/agent-instructions-shopify.md` (canonical — edit there first); a non-canonical kit-side
  lead-in precedes it, un-scoping the block from the conduct rules above and telling the model how to
  report a trip on a rail that cannot set a job exit code.
- **this repo's own CI:** `lint.yml` gained a tokenization guard asserting `claude_args` holds
  exactly four single quotes and the system prompt contains no apostrophe or `$`. One apostrophe
  typed into canonical upstream silently *truncates* the prompt — `shell-quote` does not throw, every
  flag still parses, and the wave would copy the truncated prompt fleet-wide green.
- **Piloted before the wave:** `vars.BONSAI_URL` proven to resolve against the caller, so the
  per-repo tunnel override survives the conversion. See
  [`docs/fleet-operations.md`](docs/fleet-operations.md).

### `v1.10.0` (`b394c6d`, 2026-08-02)

- **New sixth reusable: `.github/workflows/bonsai-status-sync.yml`.** Its `jobs:` body is
  byte-identical to the old per-repo copy except one added comment. Deliberately shipped without its
  caller stub — see `v1.11.0`.
- **`lint.yml` placeholder-pin guard:** fails the build on any kit stub still carrying an all-zero
  pin, so a stub that cannot resolve can never reach `main`.
- Never waved on its own; superseded by `v1.11.0` two commits later.

### `v1.9.0` (`a54c91e`, 2026-08-01, kit-only)

- **Store app secrets renamed** `DRIVER_AGENTS_SCOPES_CLIENT_ID/_SECRET` →
  `DRIVER_ENGINEERING_APP_CLIENT_ID/_SECRET`, tied to the per-org "Driver Engineering" app that
  replaced "Driver Agents Scopes" (retired 2026-08-01). Waved to all 21 targets; Avara's smoke test
  green on the new names, old-name secrets deleted.
- **Reusables unchanged.** Note this release **never got its kit repin commit** — `templates/` sat at
  `v1.8.0`'s SHA while the deployed fleet was waved to `a54c91e`, leaving the fleet a release *ahead*
  of the kit templates until `v1.11.0` closed it. That gap was invisible to
  `tools/fleet-pin-audit.sh` at the time; its reference check now catches exactly this shape — see
  [`docs/fleet-operations.md`](docs/fleet-operations.md).

### `v1.8.0` (2026-07-31, kit-only)

- **kit `claude.yml` + `shopify-tool-smoke.yml`:** `DRIVER_AGENTS_REF` → `0bbb125` (the audit
  pipeline: `SHOPIFY_AUDIT_CONTEXT` on the tool, plus the box's nightly `audit-publish.sh` —
  design at driver-agents `docs/audit-data-model.md`). Lockstep as always.
- **Audit context export:** the provisioning step now builds `SHOPIFY_AUDIT_CONTEXT`
  (ticket/issue/run/host) so every tool call's audit line says *on whose behalf* it ran. The
  Bonsai task uuid is resolved from the ISSUE body (`uuid=` param — the same linkage
  `bonsai-status-sync.yml` greps), with a `closingIssuesReferences` fallback for the
  @claude-on-a-PR rails; a human's ad-hoc `@claude` has no ticket, correctly.
- **Audit artifact upload:** a final `if: always()` `actions/upload-artifact` step (pinned
  `v7.0.1`) ships the runner's throwaway audit log to the box's nightly collector —
  `github.run_attempt` in the artifact name dodges the immutable-artifact collision on re-runs.
  Skips cleanly on repos without store tooling. Same step on the smoke test.
- **reusables: unchanged**; stubs repinned to the new tag SHA for the pin-audit invariant.

### `v1.7.0` (2026-07-31, kit-only)

- **kit `claude.yml` + `shopify-tool-smoke.yml`:** `DRIVER_AGENTS_REF` → `0404c4e` (driver-agents
  main @ 2026-07-31) — picks up the human-readable Slack alert wording (driver-agents PR #2). The
  pin moves in both files together, per the lockstep rule.
- **CI alerting leg:** the same provisioning step now writes the org-level `SHOPIFY_ALERT_WEBHOOK`
  secret (the `#driver-agents-status` incoming webhook) to the runner's throwaway disk and exports
  `SHOPIFY_ALERT_WEBHOOK_FILE` + `SHOPIFY_ALERT_HOST_LABEL`, so the admin tool's destructive/failed-
  call alerts post from Actions runs exactly as they do from the box. The alert's "where to look"
  label is the run URL — the runner's audit log doesn't outlive the job. Absent secret = alerts
  silently off, nothing else changes (the tool's own best-effort posture).
- **reusables: unchanged** (byte-identical to `v1.6.0`'s). The stubs are repinned to `3966041`
  regardless, purely so `fleet-pin-audit.sh`'s latest-tag comparison stays meaningful.

### `v1.6.0` (`0a3934f`, 2026-07-31)

- **reusables:** `actions/checkout` → `v7.0.1`, `claude-code-action` → `v1.0.183`; each Claude Code
  self-install attempt is now bounded by `timeout` — a stalled download used to hang one attempt
  until the job's wall-clock cap while the retry loop never advanced.
- **kit `claude.yml`:** human `@claude` comments always get **tag mode** (never prompt-hijacked —
  foundrae-blackridge PR #148); the ticketed round-marker branch is author-gated on
  `driver-digital-agents` + id `261291955`; optional self-skipping **Shopify admin tool**
  provisioning — pinned to a reviewed `driver-agents` revision, verified before any credential is
  written, and gated off the read-only `/code-review` rail (Avara PR #161); the same bounded
  self-install; `actions/checkout` → `v7.0.1` and `claude-code-action` → `v1.0.183`.
- **new kit file `shopify-tool-smoke.yml`** (store repos only): a manual diagnostic for the Shopify
  admin-tool wiring, upstreamed from Avara PR #161 so it is maintained here rather than reinvented
  per repo. It duplicates `claude.yml`'s provisioning step by design — same wiring, loud failures
  instead of degrade — so the two must be kept in lockstep.
- **this repo's own CI:** new `lint.yml` runs actionlint — plus shellcheck over every `run:` block —
  across the reusables **and** the kit, so a broken workflow can no longer reach consumer repos.

**Release + repin order (don't skip a step — a wave is only safe once all three are done):**

1. Merge to `main`, then cut the new tag.
   - **If the release moves `DRIVER_AGENTS_REF`**, re-run the tripwire parity check first: extract the
     `>` lines from driver-agents `docs/agent-instructions-shopify.md` at the new pin, strip the `> `
     prefixes, NFC-normalize, **collapse whitespace**, and diff against the blockquote portion of
     `claude.yml`'s `--append-system-prompt`. The whitespace collapse is mandatory — the kit flattens
     canonical's paragraph break to a single space (forced by the no-newline constraint), so a strict
     byte compare reports a false failure. **Nothing else re-checks this.** `fleet-pin-audit.sh` proves
     the fleet matches `templates/github/claude.yml` — it cannot prove that file's blockquote still
     matches canonical at the new pin, and `DRIVER_AGENTS_REF` is a raw SHA in an env var that no bot
     can bump. The audit catches a *fleet* that fell behind `templates/`; only this step catches
     `templates/` falling behind driver-agents.
2. Repin every caller stub in `templates/github/` to that tag's SHA and commit. Until this
   lands, the kit's stubs still point at the PREVIOUS tag's reusables.
   - **If the release ADDS a reusable**, its stub lands *in this step*, not in the PR that added the
     reusable — the tag it must pin does not exist until step 1. That is why
     `dependabot-keep-current`'s reusable and its stub landed in different commits, and how
     `bonsai-status-sync.yml`'s stub landed at `v1.11.0`. `lint.yml` fails the build on any stub left
     carrying a placeholder pin, so this step cannot be silently skipped.
3. Only then re-copy `templates/github/` into consumer repos (`tools/fleet-pin-audit.sh --stale`
   to confirm the fleet converged afterwards — it now checks waved file **content** against
   `templates/`, not just the pin line, and exits non-zero on any drift, so a wave can gate on it).
   - **When a full workflow becomes a stub** (as `bonsai-status-sync.yml` did — this applies to the
     v1.11.0 wave specifically), the wave diff
     contains a `templates/github/` path AND a `.github/workflows/` path with the SAME basename. The
     wave script rewrites `templates/github/` → `.github/workflows/`, so assert the rewritten diff
     touches no destination path twice before applying — otherwise the reusable can land in a client
     repo *as* the workflow, where it is `workflow_call`-only, fires on nothing, and looks green.
   - **Sed pin lines; never `git apply` them.** A pin hunk patches from whatever SHA the kit held,
     which is not necessarily what the fleet holds — at v1.11.0 the kit diff patched from `80c35fe`
     (v1.8.0) while every deployed stub held `a54c91e` (v1.9.0), a SHA no kit revision had ever
     carried in a pin line, so no diff base produced a matching `-` line and `git apply` would have
     rejected all five files on target #1.
   - Wave mechanics, the guards worth keeping, and what the pin audit cannot see:
     [`docs/fleet-operations.md`](docs/fleet-operations.md).

**Template pins are manual.** `.github/dependabot.yml` uses `directory: "/"`, which only scans
`.github/workflows/` — nothing will ever bump an action pin inside `templates/`. Check
`templates/github/claude.yml`'s `actions/checkout` + `claude-code-action` pins against the
reusables' whenever you cut a tag. The same applies to `DRIVER_AGENTS_REF` — which appears in **two**
kit files, `claude.yml` and `shopify-tool-smoke.yml`, and must carry the same pin in both or the
smoke test verifies a revision the implementer never runs — and to the `VERSION` + `SHA256` pair in
`lint.yml`, which must be bumped together or the checksum check fails the job.

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
| `bonsai-status-sync.yml` | Bonsai token only | `issues` + `pull_request` + `pull_request_review` | deterministic (no-agent) Bonsai status flips off the issue/PR lifecycle; resolves the **linked issue** and reads the task URL from the **issue** body |

**The onboarding kit lives here: `templates/github/`** (moved from `driver-bonsai-mcp` 2026-07-15). It
carries the six caller stubs above plus `claude.yml` (the implementer, still a full per-repo workflow),
`shopify-tool-smoke.yml` (store repos only), `lint.yml` (actionlint over the installing repo's own
workflows) and `pull_request_template.md`.

**Not every repo takes the whole kit.** A repo that is not on the Bonsai → PR pipeline can install
`pr-first-review.yml` + `lint.yml` alone and skip the rest as inert weight. That subset is proposed for
[`driver-agents`](https://github.com/DriverDigital/driver-agents/pull/6) and
[`driver-agents-app`](https://github.com/DriverDigital/driver-agents-app/pull/2) — **both PRs are open,
not merged**, and they should land only *after* this repo ships `templates/github/lint.yml`, since until
then the file they install has no upstream source to be re-copied from. The trade-off is written up in
`templates/github/README.md` under *Partial install*.

**`bonsai-status-sync.yml` finished converting at `v1.11.0`.** The reusable landed 2026-08-02 and its stub
landed in this tag's repin commit, so the kit now installs a 66-line stub instead of the old 190-line copy —
see *Release + repin order* above and [`docs/reusable-conversion-scope.md`](docs/reusable-conversion-scope.md).
The two-step was deliberate and matches how `dependabot-keep-current` was added: a new reusable's stub cannot
be pinned until the tag containing that reusable exists, so the reusable lands first and the stub follows in
the repin commit. `lint.yml` fails the build on any stub still carrying a placeholder pin. **The v1.11.0 wave
has landed** — `tools/fleet-pin-audit.sh` reads clean across all 21 repo@branch pairs (108 pin rows at
`90f0d066`, 127 files byte-identical to `templates/` after store-handle normalization, verified 2026-08-02),
so every consumer repo now runs the 66-line stub.

**`claude.yml` stays a per-repo copy** — that half of the conversion is tabled pending the OIDC spike (whether
Claude App token minting survives inside a cross-repo reusable), so it remains the kit's main drift surface
and the reason re-copies still need care.

Two files in `.github/workflows/` are **this repo's own CI**, not products — they are `workflow_call`-free
and never ship to the fleet: `lint.yml` (actionlint + shellcheck over the reusables *and* the kit, so a
broken workflow can't reach consumer repos) and `dependabot-auto-merge.yml` (auto-merges this repo's own
`github-owned` Dependabot bumps; the `claude-code-action` group is deliberately excluded, so those land by
hand).

**`actionlint` is a required status check on `main`** (set 2026-08-02) — before that, `lint.yml` could
report red without being able to block. Note the name collision: this repo's own `lint.yml` and the kit's
`templates/github/lint.yml` are **different files**. The kit one runs actionlint over the installing repo's
`.github/workflows/` and nothing else; this one additionally lints `templates/github/`, gates on placeholder
pins, and asserts `claude.yml`'s system prompt still tokenizes. Both use the job id `actionlint`, so the
required-check context string is the same either way. `enforce_admins` stays **`false`** here, deliberately
— which means an admin can still merge past a red `actionlint`. Requiring the check makes it binding for
everyone else and puts a red X in front of an admin who previously had nothing to override; that was worth
having on its own. Flipping the flag would break this repo's own release habit — six commits on `main`,
`v1.9.0`'s included, were pushed directly with no PR. Detail in
[`docs/fleet-operations.md`](docs/fleet-operations.md#branch-protection).

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

The `dependabot-validate` job **always runs and branches internally** (non-Dependabot PRs no-op green), and
must never be `if:`-skipped. The mechanism is worth stating precisely, because the intuitive version is
wrong: GitHub *does* accept a check run whose conclusion is `skipped`. The problem is that `if:`-skipping
the **caller** job means the reusable never starts, so the nested `validate / validate` context is never
created at all — and a required context with **no check run** for the head commit blocks forever. Reason
about whether a check run exists for the head SHA, not about the word "skipped".
After the first run on a test PR: pin the **exact required-check context GitHub reports** — for a
reusable-workflow job it is `<caller-job-id> / <reusable-job-id>`, expected **`validate / validate`** (the
workflow display name is NOT part of the context; copy the literal string from the first run's checks list).
Then confirm the `claude[bot]` author literal + `gh --create-if-none` on the runner. Require a **human**
approver (e.g. CODEOWNERS) so no bot signal
satisfies the merge gate.
