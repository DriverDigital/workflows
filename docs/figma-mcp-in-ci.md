# Figma MCP: works on the box, blocked in the CI rail

**Verdict (2026-08-02): the box can use Figma MCP today with no token work. The GitHub Actions
implementer rail (`templates/github/claude.yml`) cannot, and no `--allowedTools` edit changes that.**
`claude.yml` is deliberately unchanged.

These are two different execution environments and they fail differently. Conflating them is the easy
mistake — this doc exists to keep them apart.

## The box: already works, nothing to build

A headless `claude -p` is **not** credential-less. It cannot complete a *first-time* OAuth consent,
but it happily reuses one already completed on that machine. Verified empirically on 2026-08-02:

```
$ claude -p "Call the figma whoami tool and report its result verbatim." --allowedTools "mcp__figma"
{ "handle": "…", "email": "…", "plans": [ { "seat": "Full", "tier": "org", … } ] }
```

That is the **remote** server (`https://mcp.figma.com/mcp`), reached headlessly, with no personal
access token anywhere. Two mechanisms can deliver it, and **the box uses the second**:

- **Local `~/.claude.json` entry** + one-time interactive OAuth. Surfaces as `mcp__figma__*`. Works
  under any auth mode ("MCP servers you configure locally still work" —
  [authentication docs](https://code.claude.com/docs/en/authentication#generate-a-long-lived-token)).
  This is how Maria's laptop is set up, and it is what the `whoami` probe above exercised.
- **A claude.ai account connector** on the agents' Claude Max account. Surfaces as
  **`mcp__claude_ai_Figma__*`**. Loads only under an interactive `claude login`.

**The production box already runs the second one — do not "fix" it by adding a local entry.** The job
pack in `driver-bonsai-mcp/pipeline/` has this wired and the reasoning recorded in `triage.job.env`:

- `STRICT_MCP=0`, so the leg inherits every MCP server on the box's interactive login.
- **No `CLAUDE_CODE_OAUTH_TOKEN`** — deliberate and load-bearing. A setup-token drops every claude.ai
  connector, Figma included; proven on the box 2026-08-02. Re-adding it silently removes Figma.
- `TRIAGE_FIGMA_TOOLS="mcp__claude_ai_Figma"` in `ALLOWED_TOOLS`.

⚠️ **The prefix is `mcp__claude_ai_Figma__`, not `mcp__figma__`.** `claude mcp list` labels it
`plugin:figma:figma`, which is misleading. A wrong prefix grants nothing and fails **silently** — the
2026-07-09→15 outage shape. Adding a second, local `figma` entry on the box would create exactly that
mismatch against the existing allow-list. Don't.

(The laptop and the box differ because they are signed into **different accounts** — Maria's, versus
the agents' Max account that holds the Figma seat.)

## The CI rail: two documented gates, then Figma's own refusal

### Gate 1 — account connectors never reach CI

claude.ai account connectors (the `claude.ai <Name>` entries in `claude mcp list`, exposed as
`mcp__claude_ai_*`) are fetched server-side from the authenticated account, gated on the
`user:mcp_servers` OAuth scope. `claude setup-token` requests inference-only scope, so the token
`claude.yml` uses can never satisfy it. Both CI auth paths are excluded **by documentation**, not
inference:

- `CLAUDE_CODE_OAUTH_TOKEN` (what `claude.yml:314` uses): "It can only make model requests, so it
  can't establish Remote Control sessions or **fetch claude.ai connectors**. MCP servers you configure
  locally still work." — [authentication](https://code.claude.com/docs/en/authentication#generate-a-long-lived-token)
- `ANTHROPIC_API_KEY` (the commented-out fallback at `claude.yml:316`): connectors "aren't loaded when
  ANTHROPIC_API_KEY … is active, **even if you previously ran `/login`**. They also aren't loaded when
  `CLAUDE_CODE_OAUTH_TOKEN` holds a token from `claude setup-token`." — [mcp](https://code.claude.com/docs/en/mcp#use-mcp-servers-from-claude-ai)

### Gate 2 — a fresh runner has no credential store

`runs-on: ubuntu-latest` is a new container per run. It does not inherit the box's `~/.claude.json` or
its cached OAuth grant. The mechanism that makes the box work has nothing to attach to.

### Gate 3 — the remaining path needs a credential Figma refuses to issue

That leaves supplying the server explicitly via `--mcp-config`, which needs a **static** credential.
Figma will not issue one:

- `https://mcp.figma.com/mcp` is OAuth-only. A live unauthenticated probe returns `401` with
  `www-authenticate: Bearer … scope="mcp:connect"`.
- Figma Support on the PAT request: MCP "does not support authentication using personal access tokens
  **and this cannot be enabled**" — a refusal, not a gap.
  ([forum 47465](https://forum.figma.com/suggest-a-feature-11/support-for-pat-personal-access-token-based-auth-in-figma-remote-mcp-47465))
- Plan Access Tokens — Figma's own CI credential — authenticate against the **REST API only**.
- Figma staff: the MCP server "is not supported in GitHub Settings → Coding agent."

Also note `--allowedTools` only *permits* a tool, it never *provides* one. `mcp__github_inline_comment__*`
works because the action **bundles** that server and `prepareMcpConfig()` prefix-checks the allow-list
to decide whether to install it. No such path exists for a third-party server.

## How design→code actually works here (already built)

The triage leg reads the design and **writes what it found into the GitHub issue body**; the
implementer then works from that text and never needs Figma. This is implemented — see the
"Figma-bearing tickets" section of `driver-bonsai-mcp/pipeline/orchestrator.md`, which states the
constraint in its own words: "the agent that writes the code CANNOT see Figma … *you* are the only
step in the chain that can read the design — put what it needs in the issue body. An issue that just
links Figma sends the implementer in blind, which is worse than escalating."

Same shape as the existing `**Target branch:**` directive (`claude.yml:357-361`): triage resolves
something the implementer cannot, and hands it over as issue text. It also makes the handoff
**auditable** — the issue shows exactly what design context the implementer was given, so a bad
Figma read is visible rather than inferred from bad code.

A ticket that needs a design to be *produced or changed* still escalates to a human; triage can read
Figma, not do a design pass.

Second-order constraint: Figma's MCP rate limits attach to a **human seat** (~200 tool calls/day on
Full, 600 on Organization), not to the automation. Capturing once at triage — rather than per
implementer run and per revision round — is also what keeps that quota sane.

## Re-open tripwire

Revisit the CI rail **only** if Figma ships a non-interactive credential for `mcp.figma.com` (PAT
header, service account, or client-credentials grant). Nothing on our side changes the answer. Watch
[forum 55558](https://forum.figma.com/ask-the-community-7/token-based-authentication-support-for-figma-mcp-personal-access-token-plan-access-token-55558).

When it unblocks, the wiring is short — written down so it is not re-researched:

- **Inline JSON, never a file path.** v1.0.183 has **no `mcp_config` input** (verified against
  `action.yml` at `be7b93b`; removed in the v0→v1 migration). Servers go in via
  `claude_args: --mcp-config '{"mcpServers":{"figma":{"type":"http","url":"https://mcp.figma.com/mcp","headers":{…}}}}'`.
  A **file path is silently dropped** whenever the action contributes its own inline JSON, which is
  always true in tag mode.
- User config **merges** with the built-ins (`Object.assign` over `mcpServers`), so the inline-comment
  poster survives.
- Allow-list `mcp__figma` (bare server name is documented wildcard syntax, equivalent to `mcp__figma__*`).
  Read tools only — exclude `use_figma`, `create_new_file`, `generate_figma_design`, `upload_assets`,
  `add_code_connect_map`, `send_code_connect_mappings`.
- **`lint.yml`'s quote gate must move 4 → 6** in the same commit. It asserts `claude_args` holds exactly
  four single quotes; a third quoted flag fails the build.

## Why `claude.yml` carries no comment about this

Editing `templates/github/claude.yml` puts all **23 repo@branch pairs** out of content parity, so
`tools/fleet-pin-audit.sh --stale` goes red fleet-wide until a re-copy wave — a real wave for a comment.
Let a one-line caveat ride along with the next edit that needs a wave anyway (the queued
canonical-blockquote re-copy + `DRIVER_AGENTS_REF` bump), in the style of the existing
`WebSearch`/`WebFetch` caveat above `--allowedTools`.
