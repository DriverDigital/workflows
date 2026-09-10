# The next `claude.yml` wave — plan

What the next fleet wave of the implementer carries, what gates each item, and how a `claude.yml`
wave is run. Release mechanics live in [`README.md`](../README.md) ("Release + repin order") and
[`fleet-operations.md`](fleet-operations.md); this doc is only the *what* and the *when*.

## Where "Plan B" went

The box-retirement spec (driver-agents,
`docs/superpowers/specs/2026-08-21-box-retirement-dispatcher-design.md` §5a) named one fleet wave of
`claude.yml` as Plan B. It shipped as **`v1.13.0`** on 2026-08-22 — reviewer request from the issue
body, `## Instructions from the ticket`, Fable primary with the in-run pre-review, the nine-item
quality standard, `bonsai-status-sync` deleted fleet-wide, attribution off mechanically — and its
implementation plan was deleted in #40 once executed. Two items deliberately diverged from the spec:

- **Fable billing** was a release gate in the plan and is a watch-item now (`docs/HANDOFF.md`). It
  still needs an actual answer — whether headless `fable` draws usage credits on the Agents Max
  account — before the next wave changes anything model-side.
- **The ticketed-review prompt arm** was to be stripped; it is kept on purpose as the Macroscope
  revise-loop re-entry point (`macroscope-integration-scope.md`). Do not strip it.

`v1.14.0` and `v1.15.0` were further `claude.yml` waves (README has each). Nothing below is
un-started Plan B work; it is the ride-along list for the wave after `v1.15.0`.

## Ride-alongs for the next wave, with their gates

| Item | What changes in the kit | Gate |
|---|---|---|
| **Figma wrapper wiring** | `claude_args` gains `--mcp-config '{"mcpServers":{"figma":{…}}}'` as inline JSON (never a file path — dropped in tag mode), `--allowedTools` gains the read-only `mcp__figma__*` tools, and `lint.yml`'s quote gate moves **4 → 6** in the same commit. Wiring and tool list: [`figma-mcp-in-ci.md`](figma-mcp-in-ci.md). | The read-only REST-backed wrapper exists in driver-agents and answers one call from a throwaway Actions run. Not `mcp.figma.com`, so that doc's re-open tripwire does not apply. |
| **Figma caveat rewrite** | CAVEAT 2 above `--allowedTools` says no rail can read a design; once the wrapper is wired it says what the implementer can read (node JSON, rendered PNGs) and that writes are never offered. | Same as above. |
| **Macroscope CLI in the run** | A setup step installs the CLI with the Claude Code plugin and the issue prompt runs `/macroscope:autoloop` before the pre-review. | A non-interactive credential. The installer takes `--tools claude --yes`, but auth is a browser wizard under `~/.macroscope` and reviews bill agent credits; nothing in the docs or installer offers a token path. Ask Macroscope; same shape as the Figma blocker until answered. |
| **WebSearch / WebFetch** | Re-add to `--allowedTools`. | anthropics/claude-code-action#690 ships a fix (open as of 2026-07-28). The kit floats on `v1`, so the fix arrives on its own; the caveat comment is what gets removed. |
| **Model** | None planned; `--model fable --effort xhigh` stays. | The Fable billing answer above; fallback is `--model opus` (MODEL NOTE in `claude.yml`). |

Anything that only touches the kit and none of these gates can ride the next reusable tag instead —
cutting a tag is what creates the wave obligation, not the other way round.

## Running it

1. Edit `templates/github/claude.yml`; run the four local CI checks (`CLAUDE.md` → Commands),
   including the tokenization step, which is the only automated check on the prompt.
2. Merge, tag, repin, then `tools/fleet-wave.sh --dry-run` and canary with
   `--only vite-plugin-shopify-clean` (the pilot repo). On the canary run, assert the log does not
   contain `::warning::Skipping action due to workflow validation` — since claude-code-action#1417 a
   validation failure is a silent green skip.
3. Wave, then `tools/fleet-pin-audit.sh --stale` must read converged. All 18 `claude.yml` copies
   plus the two stub-only pairs are the 20 targets ([`fleet-operations.md`](fleet-operations.md)).
4. Run one real ticket through with the transcript on (`show_full_output`, since v1.15.0) and read
   it before calling the wave done.
