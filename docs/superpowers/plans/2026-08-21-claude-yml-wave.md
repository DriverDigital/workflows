# `claude.yml` Wave Implementation Plan (Plan B — `workflows` + fleet)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One fleet wave that (a) upgrades the implementer template `templates/github/claude.yml` — pre-review step, reviewer request, ticket instructions, Maria's quality standard, attribution off, model switch — and (b) deletes `bonsai-status-sync.yml` from every pipeline repo, now that the dispatcher in `driver-bonsai-mcp` owns status.

**Architecture:** Edit the template once; retire the status-sync reusable; add a checked-in wave script (`tools/fleet-wave.sh`, Git Data API, one atomic commit per branch, dry-run first); cut `v1.13.0`; canary the pilot repo; wave the fleet; audit. Spec: `driver-bonsai-mcp/docs/superpowers/specs/2026-08-21-box-retirement-dispatcher-design.md` §5a. Context on why this wave is allowed: Maria, 2026-08-21 — the box is gone for good; this is the one pass that sets the rail up to run without it.

**Tech Stack:** GitHub Actions, `anthropics/claude-code-action` (pin `be7b93b1907a4abad570368f3c74b6fe3807510b`, v1.0.183), bash + `gh api` (Git Data API) + `jq` + `actionlint`, the built-in Claude Code `/code-review` skill.

## Global Constraints

- `templates/github/claude.yml`'s `claude_args` must hold **exactly four single quotes** and its `--append-system-prompt` value **no apostrophe and no `$`** (`.github/workflows/lint.yml` enforces; a violation truncates the prompt silently in production).
- The `prompt:` value is a YAML double-quoted scalar wrapping a GitHub expression: inside it use **no `"`, no `'`, no `{`/`}` except `{0}`** (the issue number).
- The Shopify tripwire block inside `--append-system-prompt` (from "The next block applies to EVERY run" to the end) is canonical text owned by driver-agents `docs/agent-instructions-shopify.md` at the pinned `DRIVER_AGENTS_REF`; preserve its wording unless Task 1 step 5 refreshes it from canonical.
- `claude.yml`'s ticketed-review machinery (the `<!-- ticketed-review-round -->` prompt branch, its actor gate, and the "Re-request ticketed review" step) is a **deliberate keeper** — phase 2's re-entry point. Do not remove it.
- Waves push **directly to each branch** with the CI-skip token in the commit message (see `docs/fleet-operations.md`). Never write that token into any other commit message in this repo — in prose write `skip-ci`.
- Release order (`README.md` "Release + repin order"): merge → tag → repin `templates/github/` stubs to the tag SHA → only then wave. `lint.yml` fails on a placeholder pin.
- Fleet = every non-archived `DriverDigital` repo/branch carrying `.github/workflows/claude.yml` **or** a Dependabot caller stub (**20 pairs** today: 10 single-branch repos + Palmers × 8 branches + the 2 stub-only pairs `Team-Laird@develop` and `The-Gathery@develop`). Discover by presence, never from a list.
- Commit messages: conventional, natural language, no trailers.

---

## File structure

| Path | Responsibility |
|---|---|
| `templates/github/claude.yml` (modify) | The implementer: prompt (issues branch), `claude_args`, new `settings:` input, comment cleanup. |
| `templates/github/bonsai-status-sync.yml` (delete), `.github/workflows/bonsai-status-sync.yml` (delete) | Retired — the dispatcher polls status. SHA-pinned callers keep resolving until the wave deletes them. |
| `tools/fleet-wave.sh` (new) | The wave, checked in at last: discover targets, build one atomic commit per branch (claude.yml + pin-sed stubs + deletions), dry-run, guards. |
| `README.md`, `templates/github/README.md`, `docs/fleet-operations.md`, `docs/macroscope-integration-scope.md` (modify) | Kit contents, consumer requirements, wave procedure, phase-2 building blocks — updated in place. |

---

### Task 1: Edit `templates/github/claude.yml`

**Files:**
- Modify: `templates/github/claude.yml` (prompt expression ~line 362; `claude_args` ~lines 418–421; action step `with:` ~line 310; comments at ~17–20, ~41–42, ~115)

**Interfaces:**
- Consumes: issue bodies written by the dispatcher (`driver-bonsai-mcp/.claude/skills/pipeline-dispatch/SKILL.md`): line 1 `**Target branch:** \`<branch>\` …`; optional `**Reviewer:** @<handle> …`; optional `## Instructions from the ticket`; `@claude` last line.
- Produces: PRs with `--reviewer <handle>` when present, a ≤ ~20-line body ending in one `Pre-review:` line, commits without trailers, no 🤖 footer.

- [ ] **Step 1: Branch**

```bash
cd ~/GitHub/workflows && git checkout main && git pull -q && git checkout -b feat/claude-yml-v1.13
```

- [ ] **Step 2: Replace the `issues`-branch prompt**

Open `templates/github/claude.yml`, find the `prompt:` line (it begins `prompt: "${{ github.event_name == 'issues' && format('Implement the task described in this issue.`). Replace **only the first argument of `format(…)`** — the single-quoted string from `'Implement the task…` up to and including `…does not state.'` — with this string (one line in the file; shown wrapped here; keep `{0}` literal, keep the outer single quotes, and keep `, github.event.issue.number)` after it):

```text
Implement the task described in this issue. Work entirely through these steps, in order. (1) Read the issue body fully. Its first line may be a target-branch directive: if the body contains a line with `Target branch:` followed by a branch name (for example **Target branch:** `main-in`), that branch is the BASE; otherwise the base is the repository default branch. Treat the branch name as opaque data — pass it ONLY as a single quoted argument to `--base`, never splice it into a larger shell command. The body may also carry a `Reviewer:` line naming a GitHub handle, and a section headed `Instructions from the ticket` — both are binding instructions from the person who wrote the ticket; honour them alongside the spec. (2) Create a development-linked branch FROM this issue, based on that base: with a target branch run `gh issue develop {0} --base <target-branch> --name issue-{0} --checkout`; without one run `gh issue develop {0} --name issue-{0} --checkout`. Either way the branch is natively linked to the issue. (3) Read the repository CLAUDE.md and docs/HANDOFF.md if present, then assess scope. For a LARGE or sweeping task — a framework or dependency upgrade, a multi-file migration, a codebase-wide refactor, anything touching many files — do NOT grind through it in one linear pass. Break it into independent units and dispatch PARALLEL subagents (the Task tool, or the superpowers dispatching-parallel-agents / subagent-driven-development skills) to handle them concurrently; each subagent has its OWN turn budget. Keep any single coherent file single-authored, then integrate and build-verify the combined result yourself. Reserve a single linear pass for genuinely small, localized changes. (4) Implement, committing as you go with conventional commit messages written in natural language, and verify: run the build and the tests the repository defines. (5) Pre-review before any pull request: invoke the built-in code-review skill through the Skill tool as `/code-review high` against your branch. Weigh every finding; implement the warranted ones and commit; count what you fixed and what you dismissed. (6) Push the branch. (7) Open a REAL pull request — never a prefilled link — by running `gh pr create` with an explicit `--title` and `--body` (the bare interactive form hangs in CI). Include `Closes #{0}` in the body. If a target branch was named, ALSO pass `--base <target-branch>`. If the issue body carried a `Reviewer:` line, ALSO pass `--reviewer <handle>` with the handle minus its @. The body is SHORT: one line of purpose, a brief bulleted what-changed by area, rationale only for a genuinely odd decision, then exactly one line reading Pre-review: N findings, M fixed, K dismissed (one clause each). No narratives, no verification walkthroughs, no outstanding-issues section, no footer of any kind. The native issue-branch link plus the Closes reference connect the PR to its Bonsai task — do NOT copy any task URL into the PR. Do not invent acceptance criteria the issue does not state.
```

Check: `grep -c "'" <<<"$(sed -n '/prompt: "/p' templates/github/claude.yml)"` should equal the count before your edit (you replaced a single-quoted string with a single-quoted string and introduced no apostrophe).

- [ ] **Step 3: `claude_args` — model, and the quality standard in `--append-system-prompt`**

In the `claude_args: >-` block:

1. Change `--model opus --effort xhigh --max-turns 250` to `--model fable --effort xhigh --max-turns 250`. (Task 5 gates this on a billing check; if it fails the gate, this line goes back to `opus` before the wave.)
2. In the `--append-system-prompt '…'` value, locate the sentence that begins `The next block applies to EVERY run in this repository` and insert the following text **immediately before it** (same line, one space after the preceding sentence, one space before `The next block`). It contains no apostrophe and no `$`:

```text
How to work on an implementation run, as a matter of course: (1) Read the repository CLAUDE.md and docs/HANDOFF.md first; they carry the conventions and the current state. (2) Design before code: identify the genuine unknowns and resolve them by reading the code or, on a multi-file task, by fanning out parallel subagents for research; then write a short plan. (3) One author per coherent file: parallelise research and review at the ends, never split one file across subagents. (4) Review adversarially before any pull request: run the built-in code-review skill at level high on your branch, weigh each finding, implement what is warranted, and record what you dismissed and why. (5) Verify before claiming done: run the build and the tests the repository defines; evidence before assertions; never report a skipped step as done. (6) Commit messages are conventional commits in natural language, with no trailers and no attribution footers. (7) Pull request descriptions are short: one line of purpose, a brief bulleted what-changed by area, rationale only for a genuinely odd decision, then one line reading Pre-review: N findings, M fixed, K dismissed, and nothing else — no narratives, no verification walkthroughs, no outstanding-issues section, no generated-with footer. Detail belongs in commit messages and code comments. (8) Repository conventions win over general habits; update a doc in place rather than adding a competing one; shorter is better; never commit a secret. (9) Judgment over compliance: these defaults carry reasons, and where a reason does not apply, say so in the PR and do the better thing.
```

- [ ] **Step 4: Add the `settings:` input (attribution off, mechanically)**

In the `anthropics/claude-code-action` step's `with:` block, directly after the `claude_code_oauth_token:` line, add:

```yaml
          # Maria's rule, enforced rather than requested: no Co-Authored-By trailer on commits, no
          # "Generated with Claude Code" line in PR bodies, no session link. `attribution` supersedes
          # the deprecated includeCoAuthoredBy. Measured defect 2026-08-21 on foundrae-blackridge#168.
          settings: |
            { "attribution": { "commit": "", "pr": "", "sessionUrl": false } }
```

- [ ] **Step 5: Refresh the tripwire from canonical (update in place while the file is open)**

```bash
REF=$(grep -oE 'DRIVER_AGENTS_REF: *"?[0-9a-f]{40}' templates/github/claude.yml | grep -oE '[0-9a-f]{40}')
gh api "repos/DriverDigital/driver-agents/contents/docs/agent-instructions-shopify.md?ref=$REF" --jq .content | base64 --decode \
  | grep -E '^> ' | sed -E 's/^> ?//' | python3 -c "import sys,unicodedata;print(' '.join(unicodedata.normalize('NFC',sys.stdin.read()).split()))" > /tmp/canonical.txt
python3 - <<'PY'
import re,yaml
d=yaml.safe_load(open('templates/github/claude.yml'))
args=[s for s in d['jobs']['claude']['steps'] if 'claude_args' in s.get('with',{})][0]['with']['claude_args']
p=re.search(r"--append-system-prompt '(.*?)'(?:\s|$)",args,re.S).group(1)
kit=' '.join(p.split('All Shopify Admin API calls go through',1)[1].split())
can=' '.join(open('/tmp/canonical.txt').read().split('All Shopify Admin API calls go through',1)[1].split())
print('tripwire matches canonical' if kit==can else 'TRIPWIRE DRIFT — replace the kit block from "All Shopify Admin API calls go through" to the end of the prompt with /tmp/canonical.txt from that phrase onward')
PY
```
If it reports drift: replace that tail of the `--append-system-prompt` value with the canonical tail (same line). If the canonical text contains an apostrophe or `$`, **do not paste it** — keep the existing block and file a to-do in driver-agents (`todo-capture`): `2026-08-21 — docs/agent-instructions-shopify.md must stay free of apostrophes and $ (the kit embeds it in a single-quoted shell arg; lint rejects it) [from: workflows, claude.yml v1.13 wave]`.

- [ ] **Step 6: Drop the status-sync cascade clauses from comments**

```bash
grep -n "bonsai-status-sync" templates/github/claude.yml
```
Expected: three comment hits (near lines 17–20, 41–42, 115). Edit each so the sentence no longer claims PR events "cascade into bonsai-status-sync.yml". Replacement sentences:
- Header block (~17–20): `# The PR is authored by the Claude App. Bonsai status is polled by the pipeline dispatcher in` / `# driver-bonsai-mcp (In Progress on issue creation, Internal Review once a non-draft PR is dev-linked).`
- `id-token: write` comments (~41–42 and ~115): `# REQUIRED — mints the Claude GitHub App installation token that opens/pushes the PR as claude[bot].`

Re-run the grep: zero hits.

- [ ] **Step 7: Lint exactly as CI does**

```bash
./actionlint -color templates/github/claude.yml 2>/dev/null || actionlint templates/github/claude.yml
python3 - <<'PY'
import yaml,re,sys
d=yaml.safe_load(open("templates/github/claude.yml"))
args=[s for s in d["jobs"]["claude"]["steps"] if "claude_args" in s.get("with",{})][0]["with"]["claude_args"]
q=args.count("'"); assert q==4, f"{q} single quotes (expected 4)"
p=re.search(r"--append-system-prompt '(.*?)'(?:\s|$)",args,re.S).group(1)
assert "'" not in p and "$" not in p, "apostrophe or $ in system prompt"
prompt=[s for s in d["jobs"]["claude"]["steps"] if "prompt" in s.get("with",{})][0]["with"]["prompt"]
assert '"' not in prompt.replace('"${{','').replace('}}"',''), "double quote inside prompt expression"
print(f"ok: 4 quotes, {len(p)}-char system prompt, {len(prompt)}-char prompt expression")
PY
```
Expected: `ok: …`.

- [ ] **Step 8: Commit**

```bash
git add templates/github/claude.yml
git commit -m "feat(kit): claude.yml — in-run pre-review, reviewer + ticket directives, quality standard, attribution off, fable"
```

---

### Task 2: Retire `bonsai-status-sync` and update the kit docs

**Files:**
- Delete: `templates/github/bonsai-status-sync.yml`, `.github/workflows/bonsai-status-sync.yml`
- Modify: `README.md`, `templates/github/README.md`, `docs/fleet-operations.md`, `docs/macroscope-integration-scope.md`

- [ ] **Step 1: Delete both files**

```bash
git rm -q templates/github/bonsai-status-sync.yml .github/workflows/bonsai-status-sync.yml
```
SHA-pinned callers in the fleet keep resolving the old reusable from history until Task 6 deletes them; nothing breaks in the window.

- [ ] **Step 2: `templates/github/README.md`**

- Remove `bonsai-status-sync.yml` from the copy list (and its `cp` line) — the kit is now six files.
- Remove `BONSAI_BEARER_TOKEN` from the org-secrets list and `BONSAI_URL` from the per-repo variables.
- Replace the "Orchestrator PAT (cascade requirement)" paragraph with: `**Issue creation:** the pipeline dispatcher (driver-bonsai-mcp, a scheduled Actions workflow) opens issues as the driver-digital-agents PAT, which is what lets `claude.yml` fire on `issues: [opened]` (the default GITHUB_TOKEN cannot retrigger workflows). Bonsai status is polled by the dispatcher — no per-repo workflow is involved.`
- In the multi-branch (Palmers) note, drop "and `bonsai-status-sync.yml`".
- Add under what `claude.yml` does: `On an issue it pre-reviews its own branch with the built-in /code-review skill before opening the PR, requests the reviewer named by a **Reviewer:** line in the issue, and honours an "Instructions from the ticket" section. Commits carry no attribution trailer and PR bodies no footer (the action's settings input).`

- [ ] **Step 3: `README.md`**

- Wherever the kit's contents are enumerated, remove `bonsai-status-sync.yml`; where the six reusables are counted, make it five.
- In "Release + repin order" leave the historical mentions (they describe past waves) but add one line under step 3: `The wave is now a checked-in script: tools/fleet-wave.sh --dry-run first, then without.`

- [ ] **Step 4: `docs/fleet-operations.md`**

Under "Execution shape", replace the five-step per-target list with:
```markdown
1. `claude.yml` ← kit version, with the repo's own `SHOPIFY_STORE_NAME` restored.
2. The four stubs (`lint.yml`, `dependabot-*.yml`) ← **sed the pin line only**, so any per-repo edit survives.
3. `shopify-tool-smoke.yml` (Avara only) ← kit version, store handle restored.
4. Delete by presence anything the kit no longer ships (`bonsai-status-sync.yml` since v1.13.0).
5. `actionlint` every file about to be written, then one atomic commit (CI-skip token in the message) and patch the ref.

This is what `tools/fleet-wave.sh` does; run it with `--dry-run` first. It refuses to run if the kit's own stubs are not pinned to the latest tag (the reference-drift trap).
```

- [ ] **Step 5: `docs/macroscope-integration-scope.md`**

Where it lists `POST /tasks/reviewer-handoff` and `POST /tasks/update-status` as building blocks, add a dated note: `2026-08-21: the bridge server behind these endpoints is retired. Phase 2 writes Bonsai status through the public API (PATCH /public-api/v1/tasks/{uuid} with task_status_id) using the Agents API key, and triggers the dispatcher via workflow_dispatch { task_uuid } in driver-bonsai-mcp. The Reviewer custom field is not readable through the public API; the reviewer comes from the issue body's **Reviewer:** line instead.`

- [ ] **Step 6: Lint + commit**

```bash
actionlint .github/workflows/*.yml templates/github/*.yml
git add -A
git commit -m "feat(kit): retire bonsai-status-sync — status is polled by the dispatcher; kit is six files"
```

---

### Task 3: `tools/fleet-wave.sh` — the wave, checked in

**Files:**
- Create: `tools/fleet-wave.sh`

**Interfaces:**
- Consumes: `templates/github/*.yml` at the repo's HEAD; `gh` auth as Maria (org admin); the latest tag's SHA.
- Produces: one commit per fleet branch. Flags: `--dry-run` (default off), `--only <repo>` (canary), `--message "<text>"` (defaults to `chore(kit): claude.yml v<tag> + retire bonsai-status-sync [skip ci]`).

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# tools/fleet-wave.sh — push the kit to every fleet branch as ONE atomic commit per branch.
#
#   tools/fleet-wave.sh --dry-run            # plan only, no writes
#   tools/fleet-wave.sh --only <repo>        # a single repo (canary), all its kit branches
#   tools/fleet-wave.sh                      # the whole fleet
#   tools/fleet-wave.sh --message "chore(kit): … [skip ci]"   # override the commit message
#
# Targets are discovered by presence: every non-archived DriverDigital repo whose branch carries
# .github/workflows/claude.yml (Palmers: every branch named main*). Per target, in one commit:
#   claude.yml / shopify-tool-smoke.yml  <- kit version with the repo's SHOPIFY_STORE_NAME restored
#   lint.yml, dependabot-*.yml           <- only the `uses: DriverDigital/workflows/...@SHA` line changes
#   bonsai-status-sync.yml               <- deleted if present (kit no longer ships it)
# Guards: refuses to run unless the kit's own stubs are pinned to the latest tag's SHA; every file is
# actionlinted before it is written; no path is written twice; the store handle is asserted to
# survive; --dry-run prints the plan for the whole fleet and touches nothing.
set -euo pipefail

ORG="DriverDigital"
KIT="templates/github"
DRY=0; ONLY=""; MSG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --only) ONLY=$2; shift ;;
    --message) MSG=$2; shift ;;
    *) echo "unknown arg $1" >&2; exit 2 ;;
  esac; shift
done

command -v actionlint >/dev/null || { echo "actionlint missing (brew install actionlint)" >&2; exit 2; }
TAG=$(git describe --tags --abbrev=0)
TAG_SHA=$(git rev-list -n1 "$TAG")
MSG=${MSG:-"chore(kit): claude.yml $TAG + retire bonsai-status-sync [skip ci]"}

# Guard 1: the kit's stubs must already pin the latest tag (README release order, step 2).
if grep -rhoE "DriverDigital/workflows/[^@]+@[0-9a-f]{40}" "$KIT"/*.yml | grep -v "@$TAG_SHA" >/dev/null; then
  echo "kit stubs are not all pinned to $TAG ($TAG_SHA) — repin templates/github first" >&2; exit 2
fi

FULL_FILES="claude.yml shopify-tool-smoke.yml"          # whole-file replace (store handle restored)
PIN_FILES="lint.yml dependabot-keep-current.yml dependabot-report.yml dependabot-validate.yml"
DELETE_FILES="bonsai-status-sync.yml"

api() { gh api "$@"; }
b64() { base64 | tr -d '\n'; }
HANDLE_RE='^[[:space:]]*SHOPIFY_STORE_NAME:[[:space:]]*"[^"]*"'   # portable ERE (BSD + GNU)
handle_of() { grep -oE "$HANDLE_RE" | head -1 | sed -E 's/.*"([^"]*)"/\1/'; }

# discover targets -> "repo branch" lines
targets() {
  local repos
  if [ -n "$ONLY" ]; then repos=$ONLY; else
    repos=$(api "orgs/$ORG/repos?per_page=100&type=all" --paginate --jq '.[] | select(.archived|not) | .name')
  fi
  for r in $repos; do
    local branches
    if [ "$r" = "Palmers" ]; then
      branches=$(api "repos/$ORG/$r/branches?per_page=100" --jq '.[].name' | grep -E '^main' || true)
    else
      branches=$(api "repos/$ORG/$r" --jq .default_branch)
    fi
    for b in $branches; do
      if api "repos/$ORG/$r/contents/.github/workflows/claude.yml?ref=$b" --jq .sha >/dev/null 2>&1; then
        echo "$r $b"
      fi
    done
  done
}

fetch() { api "repos/$ORG/$1/contents/.github/workflows/$3?ref=$2" --jq .content 2>/dev/null | base64 --decode || true; }

plan_and_push() {
  local repo=$1 branch=$2 tmp; tmp=$(mktemp -d)
  local -a tree=() written=()
  local existing; existing=$(api "repos/$ORG/$repo/contents/.github/workflows?ref=$branch" --jq '.[].name')
  local changes=0

  for f in $FULL_FILES; do
    grep -qx "$f" <<<"$existing" || continue
    local cur; cur=$(fetch "$repo" "$branch" "$f")
    local handle; handle=$(handle_of <<<"$cur")
    # SHOPIFY_STORE_NAME appears once (job-level env); a global substitution is therefore exact.
    sed -E "s/^([[:space:]]*SHOPIFY_STORE_NAME:[[:space:]]*)\"[^\"]*\"/\1\"$handle\"/" "$KIT/$f" > "$tmp/$f"
    [ "$(handle_of <"$tmp/$f")" = "$handle" ] \
      || { echo "  $repo@$branch $f: store handle did not survive" >&2; exit 3; }
    if ! diff -q <(printf '%s\n' "$cur") "$tmp/$f" >/dev/null; then
      actionlint "$tmp/$f" >/dev/null; tree+=("$f"); changes=1; echo "  write  $f"
    fi
  done

  for f in $PIN_FILES; do
    grep -qx "$f" <<<"$existing" || continue
    local cur; cur=$(fetch "$repo" "$branch" "$f")
    sed -E "s#(DriverDigital/workflows/\.github/workflows/[a-z-]+\.yml@)[0-9a-f]{40}#\1$TAG_SHA#" <<<"$cur" > "$tmp/$f"
    if ! diff -q <(printf '%s\n' "$cur") "$tmp/$f" >/dev/null; then
      actionlint "$tmp/$f" >/dev/null; tree+=("$f"); changes=1; echo "  repin  $f"
    fi
  done

  local -a deletes=()
  for f in $DELETE_FILES; do
    grep -qx "$f" <<<"$existing" && { deletes+=("$f"); changes=1; echo "  delete $f"; }
  done

  [ "$changes" -eq 1 ] || { echo "  (no changes)"; rm -rf "$tmp"; return 0; }
  [ "$DRY" -eq 1 ] && { rm -rf "$tmp"; return 0; }

  # Guard: no path twice. (${arr[@]+"${arr[@]}"} is the empty-array-safe form under set -u on bash 3.2.)
  printf '%s\n' ${tree[@]+"${tree[@]}"} ${deletes[@]+"${deletes[@]}"} | sort | uniq -d | grep . && { echo "  duplicate path" >&2; exit 3; }

  local head_sha base_tree
  head_sha=$(api "repos/$ORG/$repo/git/ref/heads/$branch" --jq .object.sha)
  base_tree=$(api "repos/$ORG/$repo/git/commits/$head_sha" --jq .tree.sha)

  local entries="[]"
  for f in ${tree[@]+"${tree[@]}"}; do
    local blob; blob=$(jq -nc --arg c "$(b64 <"$tmp/$f")" '{content:$c,encoding:"base64"}' \
      | api "repos/$ORG/$repo/git/blobs" --input - --jq .sha)
    entries=$(jq -c --arg p ".github/workflows/$f" --arg s "$blob" '. + [{path:$p,mode:"100644",type:"blob",sha:$s}]' <<<"$entries")
  done
  for f in ${deletes[@]+"${deletes[@]}"}; do
    entries=$(jq -c --arg p ".github/workflows/$f" '. + [{path:$p,mode:"100644",type:"blob",sha:null}]' <<<"$entries")
  done
  local new_tree new_commit
  new_tree=$(jq -nc --arg b "$base_tree" --argjson t "$entries" '{base_tree:$b,tree:$t}' | api "repos/$ORG/$repo/git/trees" --input - --jq .sha)
  new_commit=$(jq -nc --arg m "$MSG" --arg t "$new_tree" --arg p "$head_sha" '{message:$m,tree:$t,parents:[$p]}' \
    | api "repos/$ORG/$repo/git/commits" --input - --jq .sha)
  api -X PATCH "repos/$ORG/$repo/git/refs/heads/$branch" -f sha="$new_commit" -F force=false --jq .object.sha >/dev/null
  echo "  pushed $new_commit"
  rm -rf "$tmp"
}

echo "kit tag: $TAG ($TAG_SHA)   dry-run: $DRY   message: $MSG"
n=0
while read -r repo branch; do
  [ -n "$repo" ] || continue
  echo "== $repo@$branch"; plan_and_push "$repo" "$branch"; n=$((n+1))
done < <(targets)
echo "targets: $n"
[ "$n" -gt 0 ] || { echo "no targets discovered — refusing to call that a clean fleet" >&2; exit 2; }
```

- [ ] **Step 2: Make executable; dry-run against the current fleet (before any tag — the guard should stop it)**

```bash
chmod +x tools/fleet-wave.sh
tools/fleet-wave.sh --dry-run; echo "exit=$?"
```
Expected right now: the kit is pinned to `v1.12.0` and HEAD carries an untagged Dependabot bump, so `git describe` gives `v1.12.0` and the guard passes; the dry run lists 20 targets — 18 with `write claude.yml`, `delete bonsai-status-sync.yml`, and no repins (pins already at v1.12.0), plus the two stub-only pairs showing `(no changes)`. `targets: 20`, `exit=0`. Nothing is pushed.

- [ ] **Step 3: Commit**

```bash
git add tools/fleet-wave.sh
git commit -m "feat(tools): fleet-wave.sh — the wave as a checked-in, dry-runnable script"
```

---

### Task 4: Release `v1.13.0` and repin

**Files:**
- Modify: `templates/github/{lint,dependabot-keep-current,dependabot-report,dependabot-validate}.yml` (pin lines only)

- [ ] **Step 1: PR, merge**

```bash
git push -u origin feat/claude-yml-v1.13
gh pr create --title "Kit v1.13.0: claude.yml pre-review + directives + quality standard; retire bonsai-status-sync; wave script" --body "$(cat <<'EOF'
The one-pass wave that sets the rail up to run without the box. Spec: driver-bonsai-mcp `docs/superpowers/specs/2026-08-21-box-retirement-dispatcher-design.md` §5a.

- `templates/github/claude.yml` — built-in `/code-review high` before the PR; `--reviewer` from the issue's **Reviewer:** line; honours "Instructions from the ticket"; Maria's quality standard in the system prompt; `attribution` off (no trailers, no footer); model `fable` (gated on a billing check before the wave)
- `bonsai-status-sync` retired (template + reusable) — the dispatcher polls status
- `tools/fleet-wave.sh` — the wave, checked in, dry-runnable
- docs updated in place
EOF
)"
gh pr checks --watch
gh pr merge --squash --admin --delete-branch
```

- [ ] **Step 2: Tag**

```bash
git checkout main && git pull -q
git tag -a v1.13.0 -m "claude.yml pre-review + directives + quality standard; retire bonsai-status-sync; fleet-wave.sh"
git push origin v1.13.0
```

- [ ] **Step 3: Repin the kit's stubs to the tag SHA and commit (release order step 2)**

```bash
SHA=$(git rev-list -n1 v1.13.0)
sed -i '' -E "s#^([[:space:]]*uses:[[:space:]]*DriverDigital/workflows/\.github/workflows/[a-z0-9-]+\.yml@)[0-9a-f]{40}([[:space:]]*# *v[0-9][0-9.]*)?#\1$SHA # v1.13.0#" templates/github/*.yml
grep -n "uses: DriverDigital" templates/github/*.yml     # three lines, all @$SHA # v1.13.0
git commit -am "chore: repin the kit's caller stubs to v1.13.0"
git push
tools/fleet-pin-audit.sh --stale || true   # expected: REFERENCE ok; PINS drift on all 20 pairs, CONTENT drift on the 18 full-kit pairs (that is the wave's to-do list)
```

---

### Task 5: Canary on the pilot repo + the Fable billing gate

**Files:** none (fleet state + Bonsai).

- [ ] **Step 1: Wave the pilot only**

```bash
tools/fleet-wave.sh --only vite-plugin-shopify-clean --dry-run
tools/fleet-wave.sh --only vite-plugin-shopify-clean
gh api repos/DriverDigital/vite-plugin-shopify-clean/contents/.github/workflows --jq '.[].name'   # no bonsai-status-sync.yml
```

- [ ] **Step 2: Run a real ticket through it**

Create a `[PIPELINE TEST]` ticket on project 1426641 with a reviewer directive (*"KT to review when the PR is opened"*) and one free-form instruction (*"Add a one-line changelog entry too"*), assigned to Agents, `Ready for Dev / Design`. Then from `driver-bonsai-mcp`: `gh workflow run pipeline-dispatch.yml -f dry_run=false -f task_uuid=<uuid>`. Wait for `claude.yml` to finish (`gh run list -R DriverDigital/vite-plugin-shopify-clean --workflow=claude.yml --limit 1`).

- [ ] **Step 3: Assert**

```bash
PR=$(gh pr list -R DriverDigital/vite-plugin-shopify-clean --search "PIPELINE TEST" --json number --jq '.[0].number')
gh pr view $PR -R DriverDigital/vite-plugin-shopify-clean --json reviewRequests,body,commits \
  --jq '{reviewers:[.reviewRequests[].login], body_lines:(.body|split("\n")|length), has_footer:(.body|test("Generated with")), pre_review:(.body|test("Pre-review:")), trailers:[.commits[].messageBody|select(test("Co-Authored-By"))]|length}'
```
Expected: `{"reviewers":["ktdriverdigital"],"body_lines":<≤25>,"has_footer":false,"pre_review":true,"trailers":0}`. Also confirm in the run log that `/code-review` ran before `gh pr create`, and that the changelog instruction was honoured.

- [ ] **Step 4 (Maria): the Fable billing gate**

Open the Agents account's usage page (claude.ai → settings → usage / billing) and check whether the canary run drew **usage credits** rather than plan usage. Decide:
- Credits drawn and acceptable → keep `fable`.
- Credits drawn and not acceptable, or Fable unavailable to the account → set `--model opus` in `templates/github/claude.yml`, commit as `chore(kit): claude.yml back to opus (Fable bills usage credits non-interactively)`, tag `v1.13.1`, repeat Task 4 step 3, re-wave the canary.
Record the decision in the handoff (Task 7).

- [ ] **Step 5: Clean up** — close the PR unmerged, close the issue, delete the Bonsai task.

---

### Task 6: Wave the fleet

**Files:** none.

- [ ] **Step 1: Dry-run, then wave**

```bash
tools/fleet-wave.sh --dry-run       # 20 targets; pilot shows "(no changes)"
tools/fleet-wave.sh
```
Expected: `pushed <sha>` on 19 pairs, `(no changes)` on the pilot, `targets: 20`. The two stub-only pairs show `repin` × 3 — their three Dependabot stubs and nothing else.

- [ ] **Step 2: Audit**

```bash
tools/fleet-pin-audit.sh --stale; echo "exit=$?"
```
Expected: zero drift, `exit=0`. If the audit still reports `bonsai-status-sync.yml` anywhere, that pair was not discovered (neither `claude.yml` nor a Dependabot stub) — inspect it by hand; delete the stray file the same way.

- [ ] **Step 3: Tell driver-bonsai-mcp the secret can go**

`BONSAI_BEARER_TOKEN` has no readers now: `gh secret delete BONSAI_BEARER_TOKEN --org DriverDigital` (Plan A Task 8 step 4 defers to this moment).

---

### Task 7: Handoff + to-dos

**Files:**
- Modify: `README.md` — this repo has no `docs/HANDOFF.md`; `README.md`'s **Status & versions** section is where the state lives.

- [ ] **Step 1: Record** — rewrite the **Status & versions** headline for v1.13.0 (tag SHA, date, what changed), add a new `### \`v1.13.0\`` section above `### \`v1.12.0\``, and extend the inline tag history to end at **`v1.13.0`**. The new section carries the canary assertions (numbers), the Fable outcome, the audit result, and that waves are now `tools/fleet-wave.sh`.

- [ ] **Step 2: To-dos (todo-capture)**

- `~/GitHub/driver-bonsai-mcp/CLAUDE.local.md`: `- [ ] 2026-08-21 — Phase 2: GitHub App on Vercel (Macroscope receiver, real-time PR→Internal Review, installation tokens) — spec §9; start when Macroscope's payload is known. [from: workflows, v1.13.0 wave]`
- This repo's `CLAUDE.local.md`: keep the existing Dependabot-never-bumps-pins item; add nothing new.

---

## Self-review

**Spec coverage (§5a):** item 1 (reviewer request, instructions section, cascade comments) → Task 1 steps 2, 6; item 2 (delete status-sync) → Tasks 2, 6; item 3 (three stale repos) → covered by presence-based deletion in Task 6 (the research showed the review-rail stubs are already gone; the old status-sync copies go with everything else); item 4 (Fable + in-run pre-review, concise) → Task 1 steps 2–3, gated in Task 5 step 4; item 5 (quality standard, attribution) → Task 1 steps 3–4, measured in Task 5 step 3. `tools/fleet-pin-audit.sh` end state → Task 6 step 2.

**Placeholders:** none. The Task 1 step 6 replacement comments are given verbatim; the tripwire step specifies the exact fallback.

**Consistency:** the issue-body contract (`**Target branch:**`, `**Reviewer:** @handle`, `## Instructions from the ticket`, `@claude`) matches Plan A Task 3 byte for byte. `--reviewer <handle>` strips the `@` (stated). Tag `v1.13.0` / SHA variable used identically in Tasks 3–6.
