# Macroscope integration — what was retired, the interim, and the build

Decision (Maria, 2026-08-08): Macroscope reviews every PR fleet-wide, alone — the custom review
rails are retired so it gets a clean trial. Executed at `v1.12.0`. The driver: two months of
maintenance burden (distributing workflow files, troubleshooting reviews that silently don't run,
manual re-runs) vs. a vendor product that already does the loop.

Decision (Maria, 2026-09-12): **Macroscope owns automatic PR review for the whole org, alone.** Claude
is the agentic pipeline (issue → PR, `@claude` revisions) and the on-demand second opinion (a person
`@claude`s the PR, optionally naming `/code-review`) — never an automatic reviewer. Two things left the kit's `claude.yml` on that
decision: the in-run pre-review (`/code-review high` before `gh pr create`, v1.13.0–v1.16.0) and the
`Reviewer:` → `gh pr edit --add-reviewer` arm (the dispatcher assigns the reviewer in Bonsai since
2026-09-11; Maria: no GitHub reviewer needed). Kit-only, so it reaches the fleet with the next tag.
The split is also a usage split: Claude's Max-plan usage stays on the pipeline, Macroscope bills its
own reviews. The Claude GitHub App reviews nothing on its own
(Anthropic's managed Code Review is a Team/Enterprise toggle in claude.ai admin settings, not a
Max-plan feature), and no fleet workflow runs Claude against a PR diff (fleet scan, 2026-09-12). The
one automatic Claude-on-a-PR rail left is `dependabot-report`: `workflow_run` after a Dependabot
validate, reasoning over the inert artifact, never the diff. Macroscope reviews Dependabot PRs too
since 2026-09-10, so whether that rail stays is an open question for Maria.

## What v1.12.0 retired

- **`pr-first-review.yml` + `ticketed-review.yml` caller stubs** — deleted from `templates/github/`
  and from every fleet repo. The reusables stay in `.github/workflows/` here, `workflow_call`-only
  with no callers (fire on nothing, still linted). Re-activation = restore the stubs from git
  history (pre-v1.12.0), cut a tag, wave.
- **`bonsai-status-sync`'s review leg** — the `pull_request_review` trigger and its handler
  (changes_requested → "Revisions Requested", approved → "Ready for QA"). Removed outright, not
  actor-gated: we haven't seen what Macroscope's bot does yet, and if it submits formal reviews the
  old mapping would fire with the wrong semantics (a bot approval is not "Ready for QA").
- With the rails gone, three side-effects they carried are gone too: the human-reviewer request on
  PRs, the Bonsai reviewer handoff (`/tasks/reviewer-handoff`) on ticketed PRs, and the
  claude[bot] revise loop.

## Interim state (until the build below)

- Auto-flips still live, polled by the dispatcher now: issue opened → **In Progress**; non-draft PR
  dev-linked to the issue → **Internal Review**.
- The status moves after Internal Review are **manual** (PM): Revisions Requested and Ready for QA.
  Since 2026-09-11 the dispatcher assigns the reviewer in Bonsai at Internal Review (driver-agents
  #12) and, once a person sets Revisions Requested, forwards the revisions to the PR as an `@claude`
  comment; the GitHub reviewer request `claude.yml` carried from v1.13.0 was removed 2026-09-12.
- `claude.yml` still carries the ticketed-loop machinery (round-marker prompt branch, actor gate,
  re-request step) — v1.13.0 rewrote the issue prompt around it and left it intact. It looks dead;
  it is not — it's the re-entry point below. **Do not strip it in a claude.yml wave.**

## Watch item — first Macroscope reviews

Observe on the first few PRs: the bot's login/id, whether it submits **formal** reviews
(approve / request changes) or comments only, and what its webhooks can carry. The webhook payload
is the integration's input contract; the login/id matters if any deterministic rail ever needs to
gate on it.

First observation (workflows#34, the retirement PR itself, 2026-08-08): login **`macroscopeapp`**;
two check runs ("Macroscope - Approvability Check" / "Macroscope - Correctness Check", conclusion
`skipping` — non-blocking); one PR comment with an approvability verdict ("Needs human review");
one review submitted with state **`COMMENTED`** — no formal approve/request-changes on that PR.

Second observation (workflows#41–45, 2026-08-22/24): the Approvability comment is **edited in
place** as the PR changes (same comment id, verdict text replaced — a webhook consumer must handle
`issue_comment.edited`, not just `created`); inline findings arrive as one review with inline
comments, and the bot **resolves its own threads** when a push addresses them. On #44 it issued
**a formal review, state `APPROVED`** (2026-08-24T13:36Z, after the Approvability verdict flipped
to "Approved at `cf32d5e`") — so the case the retired review leg would have mis-mapped
(bot APPROVE ≠ "Ready for QA") is real, not hypothetical, and the Phase 2 mapping must gate on
actor.

What earns the approval is **risk, not docs-versus-code**: Palmers#116, a low-risk code change,
also got a formal APPROVED review, while the behavior-changing #42/#43/#45 got "not approved —
merits human review" with **no** formal APPROVED review. The Phase 2 mapping therefore must not
gate on file type — it reads the verdict, not the diff.

One trap for the receiver: a Macroscope **spending-limit stall** ("Monthly spending limit reached",
seen on foundrae-blackridge#173) renders in the PR UI identically to a correctness refusal — no
approval, same not-approved shape. A receiver or a human has to tell the two apart before treating
"not approved" as a signal about the code.

Still unobserved: a formal REQUEST_CHANGES, and the webhook payloads — keep watching.

## The build (Phase 2 — not scheduled)

A webhook receiver owned by **driver-bonsai-mcp** (the repo that holds Bonsai access; the
2026-08-21 sketch is a GitHub App on Vercel — that repo's box-retirement spec, §9). Mapping Maria
sketched:

| Macroscope event | Action |
|---|---|
| Review finds issues | Bonsai → **Revisions Requested**; keep the task in the agents' queue; re-summon the implementer |
| Approved (all agents) | Tag a human reviewer + Bonsai → **Internal Review** (richer than the old flat mapping) |

Building blocks that already exist — reuse, don't rebuild:

- **Re-summoning the implementer:** `claude.yml`'s round-marker branch revises a PR when
  `driver-digital-agents` (id `261291955`) posts a comment carrying `<!-- ticketed-review-round -->`
  + `@claude`. The receiver posts that comment via `AGENTS_GH_PAT` and the whole revise loop comes
  back — Macroscope-driven instead of ticketed-review-driven.
- **Human handoff:** done by the dispatcher since 2026-09-11 — it assigns the Bonsai reviewer at
  Internal Review from `driver-agents/config/reviewers.json`. No GitHub reviewer request exists any
  more (removed from `claude.yml` 2026-09-12).
- **Status flips:** a public-API write too (note below); the bridge endpoint the retired sync rail
  used is gone.

2026-08-21: the bridge server that carried the old `/tasks/*` endpoints is retired. Phase 2 writes
Bonsai status through the public API (PATCH /public-api/v1/tasks/{uuid} with task_status_id) using
the Agents API key, and triggers the dispatcher via workflow_dispatch { task_uuid } in
driver-bonsai-mcp. The Reviewer custom field is not readable through the public API; the reviewer
comes from the issue body's **Reviewer:** line instead.

Open questions for the build: Macroscope's webhook auth/payload shape — moot if the Check Run agents
pilot (`docs/HANDOFF.md`, next steps) gives the receiver GitHub's own `check_run` event as its
contract; where the receiver terminates; whether the remaining two status legs (issue → In Progress,
PR → Internal Review) fold into the receiver eventually or stay with the dispatcher's polling.
