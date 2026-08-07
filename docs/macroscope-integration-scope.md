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

- Auto-flips still live: issue opened → **In Progress**; PR opened/ready/push → **Internal Review**.
- Everything after Internal Review is **manual** (PM): Revisions Requested, Ready for QA, and the
  move of a Bonsai task off **Agents** to a human reviewer. Ticketed tasks no longer ping anyone
  when the PR is ready — watch for stalls.
- `claude.yml` is untouched, including the ticketed-loop machinery (round-marker prompt branch,
  actor gate, re-request step). It looks dead; it is not — it's the re-entry point below. **Do not
  strip it in a claude.yml wave.**

## Watch item — first Macroscope reviews

Observe on the first few PRs: the bot's login/id, whether it submits **formal** reviews
(approve / request changes) or comments only, and what its webhooks can carry. The webhook payload
is the integration's input contract; the login/id matters if any deterministic rail ever needs to
gate on it.

First observation (workflows#34, the retirement PR itself, 2026-08-08): login **`macroscopeapp`**;
two check runs ("Macroscope - Approvability Check" / "Macroscope - Correctness Check", conclusion
`skipping` — non-blocking); one PR comment with an approvability verdict ("Needs human review");
one review submitted with state **`COMMENTED`** — no formal approve/request-changes on that PR.
Whether it ever submits a formal APPROVE (the case the retired review leg would have mis-mapped)
is still unobserved — keep watching.

## The build (Phase 2 — not scheduled)

A webhook receiver on the bridge server (**driver-bonsai-mcp** — it owns Bonsai access and the
endpoints). Mapping Maria sketched:

| Macroscope event | Action |
|---|---|
| Review finds issues | Bonsai → **Revisions Requested**; keep the task in the agents' queue; re-summon the implementer |
| Approved (all agents) | Tag a human reviewer + Bonsai → **Internal Review** (richer than the old flat mapping) |

Building blocks that already exist — reuse, don't rebuild:

- **Re-summoning the implementer:** `claude.yml`'s round-marker branch revises a PR when
  `driver-digital-agents` (id `261291955`) posts a comment carrying `<!-- ticketed-review-round -->`
  + `@claude`. The receiver posts that comment via `AGENTS_GH_PAT` and the whole revise loop comes
  back — Macroscope-driven instead of ticketed-review-driven.
- **Human handoff:** `POST /tasks/reviewer-handoff` (live since 2026-06-26) resolves the ticket's
  Reviewer field → GitHub handle (Maria fallback) and reassigns the Bonsai task. The GitHub-side
  reviewer request is one `gh pr edit --add-reviewer` with the same PAT.
- **Status flips:** `POST /tasks/update-status` — same endpoint the sync rail uses.

Open questions for the build: Macroscope's webhook auth/payload shape; where the receiver
terminates (the ngrok tunnel already fronts the bridge); whether the remaining two status legs
(issue → In Progress, PR → Internal Review) fold into the receiver eventually or stay as the
`bonsai-status-sync` rail. Until decided, the rail keeps both legs.
