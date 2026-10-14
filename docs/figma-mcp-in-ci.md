# Figma in the CI implementer

The implementer reads Figma through driver-agents' own Figma MCP server, not Figma's. The reusable
`.github/workflows/claude.yml` wires it in:

- `--mcp-config` passes the server inline, with the bearer `FIGMA_MCP_SECRET`. Leave the secret
  unset and the server rejects the call; the run goes on without Figma.
- `--allowedTools` allows `mcp__figma`. A bare server name is a wildcard for all its tools, and the
  whole server is safe to allow because it offers no write tool.
- `MAX_MCP_OUTPUT_TOKENS` is 200000, because node JSON runs past Claude Code's default cap.
- driver-agents `figma-mcp-smoke.yml` smoke-tests the server.

What the implementer gets:

- Node JSON from **Driver-plan files only**. A client-owned file returns 403.
- Read access only.
- Rendered images of a node through `figma_get_image` (proven by driver-agents
  `figma-mcp-smoke.yml`). The prompt does not ask for them.

The issue links the ready-for-dev frame, and the implementer reads it from there. The system prompt
gives it no Figma guidance. The server's MCP instructions carry file navigation, and todo #95's
short paragraph must not repeat them.

## Wiring rules

- Pass the server as inline JSON in `claude_args`, never as a file path. claude-code-action@v1 has
  no `mcp_config` input, and tag mode always adds its own inline `--mcp-config`, which drops a path.
- The inline config merges with the action's built-ins, so the inline-comment poster survives.
- `--allowedTools` permits a tool but never provides one. A new MCP server needs its own inline
  `--mcp-config` entry too, or its allow-list entry silently grants nothing.
- The `--mcp-config` value is one of the three single-quoted flags whose six quotes `lint.yml` counts
  in `claude_args` (CLAUDE.md, invariants). Adding another quoted flag moves that count in the same commit.

## Why not Figma's server (`mcp.figma.com`)

Three gates block it in CI:

1. **Account connectors never load.** claude.ai connectors (`mcp__claude_ai_*`) need the
   `user:mcp_servers` scope. Neither `CLAUDE_CODE_OAUTH_TOKEN` nor `ANTHROPIC_API_KEY` loads them
   ([docs](https://code.claude.com/docs/en/mcp#use-mcp-servers-from-claude-ai)).
2. **A runner has no credential store.** Each `ubuntu-latest` run starts clean, so no cached OAuth
   grant exists to reuse.
3. **Figma issues no static credential.** `mcp.figma.com` is OAuth-only. Figma refuses personal
   access tokens for MCP, and Plan Access Tokens cover the REST API only.

The rail can use Figma's server only once Figma offers a non-interactive credential (a PAT header, a
service account or a client-credentials grant). Its writers (`use_figma`, `create_new_file`,
`generate_figma_design`, `upload_assets`, `add_code_connect_map`, `send_code_connect_mappings`) would
then need excluding from the allow-list.
