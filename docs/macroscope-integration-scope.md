# Macroscope integration — what was retired, the interim, and the build

Decision (Maria, 2026-08-08): Macroscope reviews every PR fleet-wide, alone — the custom review
rails are retired so it gets a clean trial. Executed at `v1.12.0`. The driver: two months of
maintenance burden (distributing workflow files, troubleshooting reviews that silently don't run,
manual re-runs) vs. a vendor product that already does the loop.

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
- Everything after Internal Review is **manual** (PM): Revisions Requested, Ready for QA, and the
  move of a Bonsai task off **Agents** to a human reviewer. Since v1.13.0 the PR itself does ping a
  human — `claude.yml` requests the reviewer named on the issue body when it opens the PR — but
  nothing moves the Bonsai task, so that is where a ticket stalls.
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
comments, and the bot **resolves its own threads** when a push addresses them. On docs-only #44 it
issued **a formal review, state `APPROVED`** (2026-08-24T13:36Z, after the Approvability verdict
flipped to "Approved at `cf32d5e`") — so the case the retired review leg would have mis-mapped
(bot APPROVE ≠ "Ready for QA") is real, not hypothetical, and the Phase 2 mapping must gate on
actor. Behavior-changing PRs (#42/#43/#45) got "not approved — merits human review" with **no**
formal APPROVED review. Still unobserved: a formal REQUEST_CHANGES, and the webhook payloads —
keep watching.

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
- **Human handoff:** reassigning the Bonsai task is a public-API write now and the reviewer handle
  comes from the issue body (2026-08-21 note below); the GitHub-side reviewer request already ships
  in `claude.yml` (v1.13.0) — one `gh pr edit --add-reviewer` with the same PAT.
- **Status flips:** a public-API write too (note below); the bridge endpoint the retired sync rail
  used is gone.

2026-08-21: the bridge server that carried the old `/tasks/*` endpoints is retired. Phase 2 writes
Bonsai status through the public API (PATCH /public-api/v1/tasks/{uuid} with task_status_id) using
the Agents API key, and triggers the dispatcher via workflow_dispatch { task_uuid } in
driver-bonsai-mcp. The Reviewer custom field is not readable through the public API; the reviewer
comes from the issue body's **Reviewer:** line instead.

Open questions for the build: Macroscope's webhook auth/payload shape; where the receiver
terminates; whether the remaining two status legs (issue → In Progress, PR → Internal Review) fold
into the receiver eventually or stay with the dispatcher's polling.
