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
#
# Guards, in order:
#   1. the kit's own stubs must all pin the latest tag's SHA (and there must BE pins to check);
#   2. the kit repo itself is never a target — its .github/workflows/ holds the reusables;
#   3. a SHOPIFY_STORE_NAME we cannot parse aborts rather than being replaced with the kit's "";
#   4. the store handle is asserted to survive the substitution;
#   5. every file is actionlinted before it is written;
#   6. no path is written twice in one commit;
#   7. discovery failures are fatal — a short target list is never reported as a clean fleet;
#   8. --dry-run prints the plan for the whole fleet and touches nothing.
#
# Companion: tools/fleet-pin-audit.sh sees the drift; this closes it. Run the audit after a wave.
set -euo pipefail

cd "$(dirname "$0")/.."

ORG="DriverDigital"
KIT="templates/github"
SELF_REPO="workflows"          # the kit repo — never a wave target, see targets()
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
command -v jq >/dev/null        || { echo "jq missing (brew install jq)" >&2; exit 2; }
TAG=$(git describe --tags --abbrev=0)
TAG_SHA=$(git rev-list -n1 "$TAG")
MSG=${MSG:-"chore(kit): claude.yml $TAG + retire bonsai-status-sync [skip ci]"}

# Guard 1: the kit's stubs must already pin the latest tag (README release order, step 2).
# The empty case is checked too: with no pin lines at all the stale-filter finds nothing to
# complain about, and a kit that lost its `uses:` lines would sail through as "correctly pinned".
KIT_PINS=$(grep -hoE "$ORG/workflows/[^@]+@[0-9a-f]{40}" "$KIT"/*.yml || true)
[ -n "$KIT_PINS" ] || { echo "no $ORG/workflows pins found in $KIT/*.yml — the kit lost its caller stubs" >&2; exit 2; }
if printf '%s\n' "$KIT_PINS" | grep -v "@$TAG_SHA" >/dev/null; then
  echo "kit stubs are not all pinned to $TAG ($TAG_SHA) — repin templates/github first" >&2; exit 2
fi

FULL_FILES=(claude.yml shopify-tool-smoke.yml)   # whole-file replace (store handle restored)
PIN_FILES=(lint.yml dependabot-keep-current.yml dependabot-report.yml dependabot-validate.yml)
DELETE_FILES=(bonsai-status-sync.yml)

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

api() { gh api "$@"; }
# Straight to a file, never through $(...): command substitution strips ALL trailing newlines, so a
# deployed file differing from the kit only in trailing blank lines would compare equal and be
# skipped. The raw media type is the same idiom fleet-pin-audit.sh uses, and it sidesteps the
# base64 --decode portability question entirely. (`$3` before `$2` reads oddly but matches the
# repo/branch/file argument order used at both call sites.)
raw() { api "repos/$ORG/$1/contents/.github/workflows/$3?ref=$2" -H 'Accept: application/vnd.github.raw'; }
b64() { base64 | tr -d '\n'; }                                   # macOS base64 wraps at 76 cols
# Same errexit hole as targets(): the write chain is a run of `x=$(… | api …)` assignments, so a
# failed POST leaves an empty x and execution carries on. Each object is checked to be a real sha
# before the next call consumes it, so a mid-wave API failure can never walk a ref onto garbage.
sha40() { case "$1" in *[!0-9a-f]*|"") return 1;; esac; [ ${#1} -eq 40 ]; }
HANDLE_RE='^[[:space:]]*SHOPIFY_STORE_NAME:[[:space:]]*"[^"]*"'  # portable ERE (BSD + GNU)

# The per-repo store handle, or empty when the key is absent (non-store repos — and the kit ships it
# empty, so empty-in/empty-out is the correct no-op there). Only the double-quoted form is parseable,
# and a handle we cannot read is a handle we would silently overwrite with the kit's "" — which the
# survival assertion below could not catch, because "" == "" passes. So refuse instead of guessing.
# All 18 fleet targets are double-quoted today; this fires only after someone hand-edits one.
handle_of() {
  local keys quoted
  keys=$(grep -cE '^[[:space:]]*SHOPIFY_STORE_NAME:' "$1" || true)
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
# a `gh` hiccup on the Palmers branch listing would silently drop 8 of the 18 targets and print
# `targets: 10  exit=0`. An explicit `exit` in the subshell does propagate — the assignment carries
# the status, and the CALLER's errexit is live.
targets() {
  local repos r def branches b only_def
  if [ -n "$ONLY" ]; then
    # Its own statement, not interpolated into the string: a substitution embedded in a larger word
    # cannot fail the assignment, so a typo'd --only would fall through to the "no targets" message
    # and read as an empty fleet instead of a bad argument.
    only_def=$(api "repos/$ORG/$ONLY" --jq .default_branch) \
      || { echo "--only $ONLY: no such repo in $ORG" >&2; exit 2; }
    repos="$ONLY $only_def"
  else
    repos=$(gh repo list "$ORG" --limit 200 --no-archived --json name,defaultBranchRef \
              --jq '.[] | "\(.name) \(.defaultBranchRef.name)"') \
      || { echo "could not enumerate $ORG repos — this run proves nothing" >&2; exit 2; }
  fi
  while read -r r def; do
    [ -n "$r" ] || continue
    # Guard 2. The kit repo's .github/workflows/ holds the REUSABLES the whole fleet calls, and they
    # share basenames with the stubs that call them — waving into it would overwrite the rails with
    # the stubs. Presence-discovery already excludes it (no claude.yml there today); this is the belt
    # for the day that stops being true, because the mistake is fleet-wide and not one commit to undo.
    if [ "$r" = "$SELF_REPO" ]; then continue; fi
    if [ "$r" = "Palmers" ]; then
      branches=$(api "repos/$ORG/$r/branches?per_page=100" --paginate --jq '.[].name') \
        || { echo "could not list $r branches — refusing to wave a partial fleet" >&2; exit 2; }
      branches=$(printf '%s\n' "$branches" | grep -E '^main' || true)
    else
      branches=$def
    fi
    for b in $branches; do
      if api "repos/$ORG/$r/contents/.github/workflows/claude.yml?ref=$b" --jq .sha >/dev/null 2>&1; then
        echo "$r $b"
      fi
    done
  done <<<"$repos"
}

plan_and_push() {
  local repo=$1 branch=$2 tmp f cur
  tmp="$TMP/$repo/$branch"; rm -rf "$tmp"; mkdir -p "$tmp"
  local -a tree=() deletes=()
  local changes=0 existing
  existing=$(api "repos/$ORG/$repo/contents/.github/workflows?ref=$branch" --jq '.[].name') \
    || { echo "  $repo@$branch: cannot list .github/workflows" >&2; exit 3; }
  # An empty listing here would make every grep below miss and the target report "(no changes)" —
  # a repo silently dropped from the wave. It carries claude.yml by construction, so empty is a lie.
  [ -n "$existing" ] || { echo "  $repo@$branch: empty .github/workflows listing" >&2; exit 3; }

  for f in "${FULL_FILES[@]}"; do
    grep -qx "$f" <<<"$existing" || continue
    cur="$tmp/deployed-$f"; raw "$repo" "$branch" "$f" > "$cur"
    local handle; handle=$(handle_of "$cur")
    # SHOPIFY_STORE_NAME appears once as a real key (job-level env) — the other mentions in the file
    # are comments and shell, and the ^-anchored pattern skips those — so a global substitution is
    # exact. A handle carrying sed metacharacters cannot slip through silently: `/` breaks the
    # s/// parse outright, and `&` is caught by the survival assertion on the next line.
    sed -E "s/^([[:space:]]*SHOPIFY_STORE_NAME:[[:space:]]*)\"[^\"]*\"/\1\"$handle\"/" "$KIT/$f" > "$tmp/$f"
    [ "$(handle_of "$tmp/$f")" = "$handle" ] \
      || { echo "  $repo@$branch $f: store handle did not survive" >&2; exit 3; }
    if ! cmp -s "$cur" "$tmp/$f"; then
      actionlint "$tmp/$f" >/dev/null; tree+=("$f"); changes=1; echo "  write  $f"
    fi
  done

  for f in "${PIN_FILES[@]}"; do
    grep -qx "$f" <<<"$existing" || continue
    cur="$tmp/deployed-$f"; raw "$repo" "$branch" "$f" > "$cur"
    sed -E "s#($ORG/workflows/\.github/workflows/[a-z-]+\.yml@)[0-9a-f]{40}#\1$TAG_SHA#" "$cur" > "$tmp/$f"
    if ! cmp -s "$cur" "$tmp/$f"; then
      actionlint "$tmp/$f" >/dev/null; tree+=("$f"); changes=1; echo "  repin  $f"
    fi
  done

  for f in "${DELETE_FILES[@]}"; do
    if grep -qx "$f" <<<"$existing"; then deletes+=("$f"); changes=1; echo "  delete $f"; fi
  done

  [ "$changes" -eq 1 ] || { echo "  (no changes)"; return 0; }
  [ "$DRY" -eq 1 ] && return 0
  # ---- nothing above this line writes; every gh call past it does. ----

  # Guard 6: no path twice. (${arr[@]+"${arr[@]}"} is the empty-array-safe form under set -u on
  # bash 3.2.) Dead while the three lists stay disjoint — it exists for the edit that overlaps them.
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
    entries=$(jq -c --arg p ".github/workflows/$f" --arg s "$blob" \
      '. + [{path:$p,mode:"100644",type:"blob",sha:$s}]' <<<"$entries")
  done
  # `sha: null` is how the trees API deletes a path against a base_tree; jq emits a real JSON null.
  for f in ${deletes[@]+"${deletes[@]}"}; do
    entries=$(jq -c --arg p ".github/workflows/$f" \
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
# discovery process would be a background job whose exit status is never read at all, so a 12-of-18
# wave would report `targets: 12` and exit 0. Capturing it makes the status observable — see the
# errexit note on targets() for why the calls in there still need their own `|| exit`.
TARGETS=$(targets)
[ -n "$TARGETS" ] || { echo "no targets discovered — refusing to call that a clean fleet" >&2; exit 2; }
n=0
while read -r repo branch; do
  [ -n "$repo" ] || continue
  echo "== $repo@$branch"; plan_and_push "$repo" "$branch"; n=$((n+1))
done <<<"$TARGETS"
echo "targets: $n"
