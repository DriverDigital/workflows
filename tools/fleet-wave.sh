#!/usr/bin/env bash
# tools/fleet-wave.sh — push the kit to every fleet branch as ONE atomic commit per branch.
#
#   tools/fleet-wave.sh --dry-run            # plan only, no writes
#   tools/fleet-wave.sh --only <repo>        # a single repo (canary), all its kit branches
#   tools/fleet-wave.sh --skip <repo>        # leave one repo un-waved (repeatable) — e.g. to let
#                                            # Dependabot prove it bumps the stub pins there
#   tools/fleet-wave.sh                      # the whole fleet
#   tools/fleet-wave.sh --message "chore(kit): … [skip ci]"   # override the commit message
#
# Only repos carrying the driver-kit topic are targets (tools/kit-platforms.sh); within them, targets
# are discovered by presence: every enrolled non-archived DriverDigital repo whose branch carries
# claude.yml, dependabot-validate.yml, the house standards or a platform stub — the stub-only pairs
# never took the full kit but still carry pins to move (Palmers: every branch named main*).
# Per target, in one commit:
#   every kit file the branch already carries  <- kit version; the PR template and the house
#                                                 standards live at .github/, claude-settings.json
#                                                 at .claude/settings.json, the rest at
#                                                 .github/workflows/
#   pr-bonsai-link.yml, claude-standards.md,   <- also written wherever claude.yml is; the settings
#   claude-settings.json                          file's keys are merged into an existing one
#   bonsai-status-sync.yml                     <- deleted if present (kit no longer ships it)
# A platform's files (tools/kit-platforms.sh) are written only to repos whose topic names that
# platform; the cutover to a platform's stubs installs them, and the wave keeps them current.
#
# Guards, in order:
#   0. a real (non-dry) wave only runs from a clean `main` that contains the tag — dry runs anywhere;
#   1. the kit's own stubs must all pin the latest tag's SHA (and there must BE pins to check);
#   2. the kit repo itself is never a target — its .github/workflows/ holds the reusables;
#   3. a SHOPIFY_STORE_NAME we cannot parse aborts rather than being dropped unread;
#   4. a deployed store handle blocks the wave unless the repo's SHOPIFY_STORE_NAME variable holds
#      it, checked fleet-wide before the first push; the kit may carry no literal handle at all;
#   5. every file is actionlinted before it is written;
#   6. no path is written twice in one commit;
#   7. discovery failures are fatal — a short target list is never reported as a clean fleet;
#   8. --dry-run prints the plan for the whole fleet and touches nothing;
#   9. a platform file on a repo of another platform (or none), or a repo tagged with both platform
#      topics, blocks the wave before anything is written.
#
# Companion: tools/fleet-pin-audit.sh sees the drift; this closes it. Run the audit after a wave.
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=tools/kit-platforms.sh
. tools/kit-platforms.sh

ORG="DriverDigital"
KIT="templates/github"
SELF_REPO="workflows"          # the kit repo — never a wave target, see targets()
DRY=0; ONLY=""; SKIP=""; MSG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    # Non-empty is checked too: `--only "$UNSET"` would otherwise wave the whole fleet and
    # `--skip "$UNSET"` would spare nothing, each silently.
    --only) [ $# -ge 2 ] && [ -n "$2" ] || { echo "$1 needs a non-empty value" >&2; exit 2; }; ONLY=$2; shift ;;
    --skip) [ $# -ge 2 ] && [ -n "$2" ] || { echo "$1 needs a non-empty value" >&2; exit 2; }; SKIP="$SKIP $2"; shift ;;
    --message) [ $# -ge 2 ] || { echo "$1 needs a value" >&2; exit 2; }; MSG=$2; shift ;;
    *) echo "unknown arg $1" >&2; exit 2 ;;
  esac; shift
done

command -v actionlint >/dev/null || { echo "actionlint missing (brew install actionlint)" >&2; exit 2; }
command -v jq >/dev/null        || { echo "jq missing (brew install jq)" >&2; exit 2; }
TAG=$(git describe --tags --abbrev=0)
TAG_SHA=$(git rev-list -n1 "$TAG")
MSG=${MSG:-"chore(kit): repin to $TAG [skip ci]"}

# Guard 0: a real wave commits the working tree's idea of the kit under the latest tag's name, so
# the checkout has to be the released one. Guard 1 only proves the stubs agree with `git describe`
# — it passes on a feature branch whose claude.yml is already the NEXT version's content, which
# would push 20 commits labelled with a tag that does not contain what they carry. Dry runs are
# read-only and stay allowed anywhere, which is how you plan a wave from the branch that builds it.
if [ "$DRY" -eq 0 ]; then
  [ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || { echo "real waves run from main (you are on $(git rev-parse --abbrev-ref HEAD)); use --dry-run here" >&2; exit 2; }
  [ -z "$(git status --porcelain)" ] || { echo "working tree not clean" >&2; exit 2; }
  git merge-base --is-ancestor "$TAG_SHA" HEAD || { echo "$TAG ($TAG_SHA) is not an ancestor of HEAD" >&2; exit 2; }
fi

# Guard 1: the kit's stubs must already pin the latest tag (README release order, step 2).
# The empty case is checked too: with no pin lines at all the stale-filter finds nothing to
# complain about, and a kit that lost its `uses:` lines would sail through as "correctly pinned".
KIT_PINS=$(grep -hoE "$ORG/workflows/[^@]+@[0-9a-f]{40}" "$KIT"/*.yml || true)
[ -n "$KIT_PINS" ] || { echo "no $ORG/workflows pins found in $KIT/*.yml — the kit lost its caller stubs" >&2; exit 2; }
if printf '%s\n' "$KIT_PINS" | grep -v "@$TAG_SHA" >/dev/null; then
  echo "kit stubs are not all pinned to $TAG ($TAG_SHA) — repin templates/github first" >&2; exit 2
fi
# A kit file with a literal handle would overwrite a store repo's handle with "" once guard 4 is
# satisfied — the pre-v1.17.0 whole-file claude.yml carries no pin, so guard 1 cannot see it.
if grep -lE '^[[:space:]]*SHOPIFY_STORE_NAME:[[:space:]]*"' "$KIT"/*.yml; then
  echo "the kit files above carry a literal SHOPIFY_STORE_NAME — it belongs in the repo variable" >&2; exit 2
fi

# Every kit file a target carries is replaced with the kit's copy — the stubs too, since v1.15.0.
# A pin-line sed used to let per-repo stub edits survive, but fleet-pin-audit.sh reports any such
# edit as drift, so nothing the kit does not ship should outlive a wave. No kit file carries a
# per-repo value: the store handle is the SHOPIFY_STORE_NAME repository variable (guard 4).
FULL_FILES=(claude.yml shopify-tool-smoke.yml shopify-theme.yml vercel-deploy.yml lint.yml
            pr-bonsai-link.yml dependabot-keep-current.yml dependabot-report.yml
            dependabot-validate.yml pull_request_template.md claude-standards.md claude-settings.json)
DELETE_FILES=(bonsai-status-sync.yml)
# Where a kit file lives in a target repo: the PR template and the house standards sit in .github/,
# and the shared Claude Code project settings are the repo's .claude/settings.json.
dest() {
  case "$1" in
    pull_request_template.md|claude-standards.md) echo ".github/$1" ;;
    claude-settings.json) echo ".claude/settings.json" ;;
    *) echo ".github/workflows/$1" ;;
  esac
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

api() { gh api "$@"; }
# A typo in --skip would skip nothing and wave the repo it was meant to spare — the one outcome the
# flag exists to prevent — so each name is resolved, and the RESOLVED name is what gets matched:
# the API is case-insensitive (`palmers` resolves) but the match against `gh repo list` is not.
canon=""
for s in $SKIP; do
  c=$(api "repos/$ORG/$s" --jq .name) || { echo "--skip $s: no such repo in $ORG" >&2; exit 2; }
  canon="$canon $c"
done
SKIP=$canon
# Straight to a file, never through $(...): command substitution strips ALL trailing newlines, so a
# deployed file differing from the kit only in trailing blank lines would compare equal and be
# skipped. The raw media type is the same idiom fleet-pin-audit.sh uses, and it sidesteps the
# base64 --decode portability question entirely. (`$3` before `$2` reads oddly but matches the
# repo/branch/file argument order used at both call sites.)
raw() { api "repos/$ORG/$1/contents/$(dest "$3")?ref=$2" -H 'Accept: application/vnd.github.raw'; }
b64() { base64 | tr -d '\n'; }                                   # macOS base64 wraps at 76 cols
# Not for the failed-POST case: plan_and_push runs straight in the loop, not in a command
# substitution (the errexit hole targets() documents), so a failing api call aborts the wave on its
# own. This is for the 2xx that returns a body we did not expect — nothing fails, and the empty
# value would be handed to the next call. Checked at each step, a surprise response can never walk
# a ref onto garbage.
sha40() { case "$1" in *[!0-9a-f]*|"") return 1;; esac; [ ${#1} -eq 40 ]; }
HANDLE_RE='^[[:space:]]*SHOPIFY_STORE_NAME:[[:space:]]*"[^"]*"'  # portable ERE (BSD + GNU)

# The store handle a pre-v1.17.0 file carries, or empty when the key is absent, empty, or reads
# `vars`. Only the double-quoted form is parseable, and a handle we cannot read is a handle guard 4
# cannot check — so refuse instead of guessing.
handle_of() {
  local keys quoted
  keys=$(grep -E '^[[:space:]]*SHOPIFY_STORE_NAME:' "$1" \
    | grep -cvE '^[[:space:]]*SHOPIFY_STORE_NAME:[[:space:]]*\$\{\{ vars\.SHOPIFY_STORE_NAME \}\}[[:space:]]*$' || true)
  quoted=$(grep -cE "$HANDLE_RE" "$1" || true)
  [ "$keys" = "$quoted" ] || { echo "$1: SHOPIFY_STORE_NAME is not a double-quoted value" >&2; return 3; }
  sed -nE 's/^[[:space:]]*SHOPIFY_STORE_NAME:[[:space:]]*"([^"]*)".*/\1/p' "$1" | head -1
}

# discover targets -> "repo branch" lines.
#
# Every gh call here carries its own `|| exit`, and that is not belt-and-braces: `set -e` is
# SUPPRESSED inside a command substitution that is part of an assignment, and this function is only
# ever called as `TARGETS=$(targets)`. Verified on bash 3.2.57 — `f(){ local x; x=$(false); echo
# reached; }; T=$(f)` prints `reached` and exits 0. So errexit cannot be relied on to stop a wave
# here, and a half-read fleet is the one failure this whole script must never report as success:
# a `gh` hiccup on the Palmers branch listing would silently drop 8 of the 20 targets and print
# `targets: 12  exit=0`. An explicit `exit` in the subshell does propagate — the assignment carries
# the status, and the CALLER's errexit is live.
targets() {
  local repos r def topics plat branches b
  if [ -n "$ONLY" ]; then
    # Its own statement, not interpolated into the string: a substitution embedded in a larger word
    # cannot fail the assignment, so a typo'd --only would fall through to the "no targets" message
    # and read as an empty fleet instead of a bad argument. The resolved name is used, not the
    # typed one: `--only palmers` resolves, but the literal Palmers branch check below would not.
    repos=$(api "repos/$ORG/$ONLY" --jq '"\(.name) \(.default_branch) \(.topics | join(","))"') \
      || { echo "--only $ONLY: no such repo in $ORG" >&2; exit 2; }
  else
    repos=$(gh repo list "$ORG" --limit 200 --no-archived --json name,defaultBranchRef,repositoryTopics \
              --jq '.[] | "\(.name) \(.defaultBranchRef.name) \([(.repositoryTopics // [])[].name] | join(","))"') \
      || { echo "could not enumerate $ORG repos — this run proves nothing" >&2; exit 2; }
    # A fleet that grew past --limit would come back silently truncated, and the missing repos would
    # read as "not a target" rather than "not looked at".
    [ "$(printf '%s\n' "$repos" | wc -l)" -lt 200 ] \
      || { echo "repo list hit the --limit; raise it" >&2; exit 2; }
  fi
  while read -r r def topics; do
    [ -n "$r" ] || continue
    # Guard 2. The kit repo's .github/workflows/ holds the REUSABLES the whole fleet calls, and they
    # share basenames with the stubs that call them — waving into it would overwrite the rails with
    # the stubs. Discovery does NOT exclude it: the OR probe below matches on claude.yml OR
    # dependabot-validate.yml, and this repo carries the latter, so this skip is the only thing
    # keeping the wave out of the kit — and the mistake is fleet-wide, not one commit to undo.
    if [ "$r" = "$SELF_REPO" ]; then continue; fi
    case " $SKIP " in *" $r "*) echo "skip   $r (--skip)" >&2; continue ;; esac
    if ! topics_enrolled "${topics//,/ }"; then
      [ -z "$ONLY" ] || { echo "--only $r: the repo has no $KIT_TOPIC topic, so it takes no kit" >&2; exit 2; }
      continue
    fi
    plat=$(topics_platform "${topics//,/ }")
    [ "$plat" != both ] || { echo "$r carries both shopify-theme and vercel-site topics — pick one" >&2; exit 2; }
    if [ "$r" = "Palmers" ]; then
      branches=$(api "repos/$ORG/$r/branches?per_page=100" --paginate --jq '.[].name') \
        || { echo "could not list $r branches — refusing to wave a partial fleet" >&2; exit 2; }
      branches=$(printf '%s\n' "$branches" | grep -E '^main' || true)
    else
      branches=$def
    fi
    # A branch is a target when it carries claude.yml, dependabot-validate.yml, claude-standards.md or
    # a platform stub: the stub-only pairs hold nothing but the three Dependabot stubs, a lint-only repo
    # may hold just the standards, and a theme repo may hold only its platform stub; skipping any would
    # leave drift fleet-pin-audit.sh --stale reports for ever.
    # Each probe runs only when the one before 404s; plan_and_push skips files a target does not have.
    for b in $branches; do
      if api "repos/$ORG/$r/contents/.github/workflows/claude.yml?ref=$b" --jq .sha >/dev/null 2>&1 \
         || api "repos/$ORG/$r/contents/.github/workflows/dependabot-validate.yml?ref=$b" --jq .sha >/dev/null 2>&1 \
         || api "repos/$ORG/$r/contents/.github/claude-standards.md?ref=$b" --jq .sha >/dev/null 2>&1 \
         || api "repos/$ORG/$r/contents/.github/workflows/shopify-theme.yml?ref=$b" --jq .sha >/dev/null 2>&1 \
         || api "repos/$ORG/$r/contents/.github/workflows/vercel-deploy.yml?ref=$b" --jq .sha >/dev/null 2>&1; then
        echo "$r $b $plat"
      fi
    done
  done <<<"$repos"
}

plan_and_push() {
  local repo=$1 branch=$2 plat=$3 tmp f fp cur
  tmp="$TMP/$repo/$branch"; rm -rf "$tmp"; mkdir -p "$tmp"
  local -a tree=() deletes=()
  local changes=0 existing rootdirs dotgithub workflows dotclaude kit_paths
  # Each listing is its own assignment so a failure cannot hide behind another (errexit is off inside
  # an assignment's substitution). A standards-only target has no .github/workflows, so that listing
  # runs only when .github says the directory exists.
  dotgithub=$(api "repos/$ORG/$repo/contents/.github?ref=$branch" --jq '.[] | "\(.type) \(.path)"') \
    || { echo "  $repo@$branch: cannot list .github" >&2; exit 3; }
  existing=$(sed -n 's/^file //p' <<<"$dotgithub")
  if grep -qxF "dir .github/workflows" <<<"$dotgithub"; then
    workflows=$(api "repos/$ORG/$repo/contents/.github/workflows?ref=$branch" --jq '.[].path') \
      || { echo "  $repo@$branch: cannot list .github/workflows" >&2; exit 3; }
    existing="$existing"$'\n'"$workflows"
  fi
  rootdirs=$(api "repos/$ORG/$repo/contents?ref=$branch" --jq '.[] | select(.type == "dir") | .path') \
    || { echo "  $repo@$branch: cannot list the repo root" >&2; exit 3; }
  if grep -qxF .claude <<<"$rootdirs"; then
    dotclaude=$(api "repos/$ORG/$repo/contents/.claude?ref=$branch" --jq '.[].path') \
      || { echo "  $repo@$branch: cannot list .claude" >&2; exit 3; }
    existing="$existing"$'\n'"$dotclaude"
  fi
  # Discovery proved the target carries at least one kit file, so a listing with none is a lie — and
  # would otherwise report "(no changes)", silently dropping the repo from the wave.
  kit_paths=$(for f in "${FULL_FILES[@]}"; do dest "$f"; done)
  grep -qxFf <(printf '%s\n' "$kit_paths") <<<"$existing" \
    || { echo "  $repo@$branch: no kit file in the .github listings" >&2; exit 3; }

  # Three files are installed beside claude.yml, not only refreshed where present: the Bonsai-link
  # check, the house standards (whose CLAUDE.md import stays a per-repo edit) and the shared Claude
  # Code project settings. Nothing outside .github/ and .claude/ is ever written.
  for f in "${FULL_FILES[@]}"; do
    # Guard 9, per file: a platform file is never written to a repo of another platform, and one
    # already there blocks the wave instead of being refreshed into place.
    fp=$(file_platform "$f")
    if [ -n "$fp" ] && [ "$fp" != "$plat" ]; then
      if grep -qxF "$(dest "$f")" <<<"$existing"; then
        echo "  $repo@$branch $f: a $fp file, but the repo's platform topic says $plat" >&2
        BLOCKED=1
      fi
      continue
    fi
    grep -qxF "$(dest "$f")" <<<"$existing" \
      || { case "$f" in pr-bonsai-link.yml|claude-standards.md|claude-settings.json) grep -qxF .github/workflows/claude.yml <<<"$existing" ;; *) false ;; esac; } \
      || continue
    # errexit would abort on the cp's missing source anyway; this fails with a clear message and
    # exit 3 before the network fetch. If the kit dropped it on purpose it belongs in DELETE_FILES.
    [ -f "$KIT/$f" ] \
      || { echo "  $repo@$branch $f: not in the kit any more — move it to DELETE_FILES?" >&2; exit 3; }
    cur="$tmp/deployed-$f"; : > "$cur"
    grep -qxF "$(dest "$f")" <<<"$existing" && raw "$repo" "$branch" "$f" > "$cur"
    local handle; handle=$(handle_of "$cur")
    # Replacing a file that still carries its handle would switch store tooling off without a
    # sound — the provisioning step self-skips on an empty handle.
    if [ -n "$handle" ]; then
      local var; var=$(api "repos/$ORG/$repo/actions/variables/SHOPIFY_STORE_NAME" --jq .value 2>/dev/null) || var="(unset or unreadable)"
      if [ "$var" != "$handle" ]; then
        echo "  $repo@$branch $f: repository variable SHOPIFY_STORE_NAME must be '$handle', reads $var" >&2
        BLOCKED=1; return 0
      fi
    fi
    # The repo owns the rest of its .claude/settings.json; the kit owns only the keys it ships.
    if [ "$f" = claude-settings.json ] && [ -s "$cur" ]; then
      jq -s '.[0] * .[1]' "$cur" "$KIT/$f" > "$tmp/$f" \
        || { echo "  $repo@$branch .claude/settings.json: not valid JSON, so the kit keys cannot be merged in" >&2; exit 3; }
    else
      cp "$KIT/$f" "$tmp/$f"
    fi
    if ! cmp -s "$cur" "$tmp/$f"; then
      case "$f" in *.yml) actionlint "$tmp/$f" || { echo "  $repo@$branch $f: actionlint failed" >&2; exit 3; } ;; esac
      tree+=("$f"); changes=1; echo "  write  $f"
    fi
  done

  for f in "${DELETE_FILES[@]}"; do
    if grep -qxF "$(dest "$f")" <<<"$existing"; then deletes+=("$f"); changes=1; echo "  delete $f"; fi
  done

  [ "$changes" -eq 1 ] || { echo "  (no changes)"; return 0; }
  [ "$DRY" -eq 1 ] && return 0
  # ---- nothing above this line writes; every gh call past it does. ----

  # Guard 6: no path twice. (${arr[@]+"${arr[@]}"} is the empty-array-safe form under set -u on
  # bash 3.2.) Dead while the two lists stay disjoint — it exists for the edit that overlaps them.
  if printf '%s\n' ${tree[@]+"${tree[@]}"} ${deletes[@]+"${deletes[@]}"} | sort | uniq -d | grep .; then
    echo "  duplicate path" >&2; exit 3
  fi

  local head_sha base_tree entries blob new_tree new_commit
  head_sha=$(api "repos/$ORG/$repo/git/ref/heads/$branch" --jq .object.sha)
  base_tree=$(api "repos/$ORG/$repo/git/commits/$head_sha" --jq .tree.sha)

  entries="[]"
  for f in ${tree[@]+"${tree[@]}"}; do
    blob=$(jq -nc --arg c "$(b64 <"$tmp/$f")" '{content:$c,encoding:"base64"}' \
      | api "repos/$ORG/$repo/git/blobs" --input - --jq .sha)
    sha40 "$blob" || { echo "  $repo@$branch $f: blob create returned no sha" >&2; exit 3; }
    entries=$(jq -c --arg p "$(dest "$f")" --arg s "$blob" \
      '. + [{path:$p,mode:"100644",type:"blob",sha:$s}]' <<<"$entries")
  done
  # `sha: null` is how the trees API deletes a path against a base_tree; jq emits a real JSON null.
  for f in ${deletes[@]+"${deletes[@]}"}; do
    entries=$(jq -c --arg p "$(dest "$f")" \
      '. + [{path:$p,mode:"100644",type:"blob",sha:null}]' <<<"$entries")
  done
  new_tree=$(jq -nc --arg b "$base_tree" --argjson t "$entries" '{base_tree:$b,tree:$t}' \
    | api "repos/$ORG/$repo/git/trees" --input - --jq .sha)
  sha40 "$new_tree" || { echo "  $repo@$branch: tree create returned no sha" >&2; exit 3; }
  new_commit=$(jq -nc --arg m "$MSG" --arg t "$new_tree" --arg p "$head_sha" \
    '{message:$m,tree:$t,parents:[$p]}' | api "repos/$ORG/$repo/git/commits" --input - --jq .sha)
  sha40 "$new_commit" || { echo "  $repo@$branch: commit create returned no sha" >&2; exit 3; }
  # -F sends a JSON boolean (verified: gh 2.98.0 encodes `-F k=false` as `"k": false`), so this is a
  # fast-forward-only update — it fails rather than clobbering a branch that moved under us.
  api -X PATCH "repos/$ORG/$repo/git/refs/heads/$branch" -f sha="$new_commit" -F force=false --jq .object.sha >/dev/null
  echo "  pushed $new_commit"
}

echo "kit tag: $TAG ($TAG_SHA)   dry-run: $DRY   message: $MSG"
# Guard 7: resolve the whole plan before touching anything. Fed straight from `< <(targets)` the
# discovery process would be a background job whose exit status is never read at all, so a 12-of-20
# wave would report `targets: 12` and exit 0. Capturing it makes the status observable — see the
# errexit note on targets() for why the calls in there still need their own `|| exit`.
TARGETS=$(targets)
BLOCKED=0
[ -n "$TARGETS" ] || { echo "no targets discovered — refusing to call that a clean fleet" >&2; exit 2; }
# Guard 4 is checked across the whole fleet before the first push: a real wave plans every target
# silently first, so a blocked repo stops it before anything is written rather than halfway.
if [ "$DRY" -eq 0 ]; then
  DRY=1
  # Called from an `if` body, never as the right side of `||`: that context disables errexit for
  # the whole function, and a failed read would then plan on as if nothing happened.
  while read -r repo branch plat; do if [ -n "$repo" ]; then plan_and_push "$repo" "$branch" "$plat" >/dev/null; fi; done <<<"$TARGETS"
  DRY=0
  [ "$BLOCKED" -eq 0 ] || { echo "refusing to wave: fix the blocked targets above first" >&2; exit 3; }
fi
n=0
while read -r repo branch plat; do
  [ -n "$repo" ] || continue
  echo "== $repo@$branch ($plat)"; plan_and_push "$repo" "$branch" "$plat"; n=$((n+1))
done <<<"$TARGETS"
echo "targets: $n"
[ "$BLOCKED" -eq 0 ] || { echo "blocked targets above — a real wave would stop before writing anything" >&2; exit 3; }
