# Macroscope integration — what was retired, and the loop that replaced it

Decision (Maria, 2026-08-08): Macroscope reviews every PR fleet-wide, alone — the custom review
rails are retired so it gets a clean trial. Executed at `v1.12.0`. The driver: two months of
maintenance burden (distributing workflow files, troubleshooting reviews that silently don't run,
manual re-runs) vs. a vendor product that already does the loop.

Decision (Maria, 2026-09-12): **Macroscope owns automatic PR review for the whole org, alone.** Claude
is the agentic pipeline (issue → PR, `@claude` revisions) and the on-demand second opinion (a person
`@claude`s the PR, optionally naming `/code-review`) — never an automatic reviewer of an opened PR.
What the implementer does to its own branch before it opens the PR (the in-run `/code-review high`
pass and the `Pre-review:` body line, v1.13.0) is implementing, not PR review, and **stays**. Verified
the same day, so nothing in the kit had to change: no fleet workflow runs Claude on a `pull_request`
event (45 repo/branch pairs scanned), the Claude GitHub App reviews nothing on its own (Anthropic's
managed Code Review is a Team/Enterprise toggle in claude.ai admin settings, not a Max-plan feature),
and the only Claude-driven automatic verdict on a PR is `dependabot-report` — `workflow_run` after a
Dependabot validate, reasoning over the inert artifact, never the diff. Macroscope reviews Dependabot
PRs too since 2026-09-10, so whether that rail stays is an open question for Maria. The split is also
a usage split: Claude's Max-plan usage stays on the pipeline, Macroscope bills its own reviews.

## What v1.12.0 retired

- **`pr-first-review.yml` + `ticketed-review.yml` caller stubs** — deleted from `templates/github/`
  and from every fleet repo. The reusables stayed here caller-less until 2026-09-30, when they were
  deleted too; any tag through `v1.16.0` still holds them.
- **`bonsai-status-sync`'s review leg** — the `pull_request_review` trigger and its handler
  (changes_requested → "Revisions Requested", approved → "Ready for QA"). Removed outright, not
  actor-gated: we haven't seen what Macroscope's bot does yet, and if it submits formal reviews the
  old mapping would fire with the wrong semantics (a bot approval is not "Ready for QA").
- With the rails gone, three side-effects they carried are gone too: the human-reviewer request on
  PRs, the Bonsai reviewer handoff (`/tasks/reviewer-handoff`) on ticketed PRs, and the
  claude[bot] revise loop.

## The loop (driver-agents, since 2026-09-18)

The revise loop lives in the driver-agents dispatcher (#34), not in the kit. Each hourly fire derives a
claude[bot] PR's review state from GitHub, and while Macroscope has unresolved findings it posts at most
one plain top-level `@claude` comment (tag mode, admitted by `claude.yml`'s `driver-digital-agents`
carve-out), capped at three turns per PR; it holds the Bonsai hand-off until the loop exits. Design:
driver-agents `docs/superpowers/specs/2026-09-18-macroscope-review-loop-design.md`.

- Status: issue opened → **In Progress** and PR → **Internal Review** are the dispatcher's polling;
  the dispatcher assigns the Bonsai reviewer at Internal Review, and the Bonsai assignment is the
  review request. Revisions Requested and Ready for QA stay manual (PM); a Revisions Requested ticket
  is forwarded to the PR as an `@claude` comment.
- The kit's round-marker prompt arm and "Re-request ticketed review" step were **not** used — agent
  mode never shows the model the comment, and the step posts a false "Revisions addressed". They go
  in the next `claude.yml` wave with the `--add-reviewer` step ([`claude-yml-wave-plan.md`](claude-yml-wave-plan.md)).
- The Phase 2 Macroscope → Bonsai webhook receiver was **retired unbuilt** (Maria, 2026-09-29,
  driver-agents #41): the dispatcher does both legs, and Macroscope has no outbound review webhook.

## Watch item — first Macroscope reviews

Observe on the first few PRs: the bot's login/id, whether it submits **formal** reviews
(approve / request changes) or comments only. The login/id matters wherever a deterministic rail
gates on it — the dispatcher's loop does.

First observation (workflows#34, the retirement PR itself, 2026-08-08): login **`macroscopeapp`**;
two check runs ("Macroscope - Approvability Check" / "Macroscope - Correctness Check", conclusion
`skipping` — non-blocking); one PR comment with an approvability verdict ("Needs human review");
one review submitted with state **`COMMENTED`** — no formal approve/request-changes on that PR.

Second observation (workflows#41–45, 2026-08-22/24): the Approvability comment is **edited in
place** as the PR changes (same comment id, verdict text replaced — a reader must take the current body, not the first); inline findings arrive as one review with inline
comments, and the bot **resolves its own threads** when a push addresses them. On #44 it issued
**a formal review, state `APPROVED`** (2026-08-24T13:36Z, after the Approvability verdict flipped
to "Approved at `cf32d5e`") — so the case the retired review leg would have mis-mapped
(bot APPROVE ≠ "Ready for QA") is real, not hypothetical, and any status mapping must gate on
actor.

What earns the approval is **risk, not docs-versus-code**: Palmers#116, a low-risk code change,
also got a formal APPROVED review, while the behavior-changing #42/#43/#45 got "not approved —
merits human review" with **no** formal APPROVED review. A status mapping therefore must not
gate on file type — it reads the verdict, not the diff.

One trap for the loop: a Macroscope **spending-limit stall** ("Monthly spending limit reached",
seen on foundrae-blackridge#173) renders in the PR UI identically to a correctness refusal — no
approval, same not-approved shape. The dispatcher or a human has to tell the two apart before treating
"not approved" as a signal about the code.

Still unobserved: a formal REQUEST_CHANGES.
