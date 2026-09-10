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
# Targets are discovered by presence: every non-archived DriverDigital repo whose branch carries
# .github/workflows/claude.yml OR .github/workflows/dependabot-validate.yml — the stub-only pairs
# never took the full kit but still carry pins to move (Palmers: every branch named main*).
# Per target, in one commit:
#   every kit file the branch already carries  <- kit version (claude.yml's store handle restored);
#                                                 the PR template lives at .github/, the rest at
#                                                 .github/workflows/
#   bonsai-status-sync.yml                     <- deleted if present (kit no longer ships it)
#
# Guards, in order:
#   0. a real (non-dry) wave only runs from a clean `main` that contains the tag — dry runs anywhere;
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

# Every kit file a target carries is replaced with the kit's copy — the stubs too, since v1.15.0.
# A pin-line sed used to let per-repo stub edits survive, but fleet-pin-audit.sh reports any such
# edit as drift, so nothing the kit does not ship should outlive a wave. The store handle in
# claude.yml / shopify-tool-smoke.yml is the one per-repo value, restored below.
FULL_FILES=(claude.yml shopify-tool-smoke.yml lint.yml
            dependabot-keep-current.yml dependabot-report.yml dependabot-validate.yml
            pull_request_template.md)
DELETE_FILES=(bonsai-status-sync.yml)
# Where a kit file lives in a target repo: the PR template is the one outside .github/workflows/.
dest() { case "$1" in pull_request_template.md) echo ".github/$1" ;; *) echo ".github/workflows/$1" ;; esac; }

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

# The per-repo store handle, or empty when the key is absent (non-store repos — and the kit ships it
# empty, so empty-in/empty-out is the correct no-op there). Only the double-quoted form is parseable,
# and a handle we cannot read is a handle we would silently overwrite with the kit's "" — which the
# survival assertion below could not catch, because "" == "" passes. So refuse instead of guessing.
# All 18 full-kit targets are double-quoted today; this fires only after someone hand-edits one.
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
# a `gh` hiccup on the Palmers branch listing would silently drop 8 of the 20 targets and print
# `targets: 12  exit=0`. An explicit `exit` in the subshell does propagate — the assignment carries
# the status, and the CALLER's errexit is live.
targets() {
  local repos r def branches b
  if [ -n "$ONLY" ]; then
    # Its own statement, not interpolated into the string: a substitution embedded in a larger word
    # cannot fail the assignment, so a typo'd --only would fall through to the "no targets" message
    # and read as an empty fleet instead of a bad argument. The resolved name is used, not the
    # typed one: `--only palmers` resolves, but the literal Palmers branch check below would not.
    repos=$(api "repos/$ORG/$ONLY" --jq '"\(.name) \(.default_branch)"') \
      || { echo "--only $ONLY: no such repo in $ORG" >&2; exit 2; }
  else
    repos=$(gh repo list "$ORG" --limit 200 --no-archived --json name,defaultBranchRef \
              --jq '.[] | "\(.name) \(.defaultBranchRef.name)"') \
      || { echo "could not enumerate $ORG repos — this run proves nothing" >&2; exit 2; }
    # A fleet that grew past --limit would come back silently truncated, and the missing repos would
    # read as "not a target" rather than "not looked at".
    [ "$(printf '%s\n' "$repos" | wc -l)" -lt 200 ] \
      || { echo "repo list hit the --limit; raise it" >&2; exit 2; }
  fi
  while read -r r def; do
    [ -n "$r" ] || continue
    # Guard 2. The kit repo's .github/workflows/ holds the REUSABLES the whole fleet calls, and they
    # share basenames with the stubs that call them — waving into it would overwrite the rails with
    # the stubs. Discovery does NOT exclude it: the OR probe below matches on claude.yml OR
    # dependabot-validate.yml, and this repo carries the latter, so this skip is the only thing
    # keeping the wave out of the kit — and the mistake is fleet-wide, not one commit to undo.
    if [ "$r" = "$SELF_REPO" ]; then continue; fi
    case " $SKIP " in *" $r "*) echo "skip   $r (--skip)" >&2; continue ;; esac
    if [ "$r" = "Palmers" ]; then
      branches=$(api "repos/$ORG/$r/branches?per_page=100" --paginate --jq '.[].name') \
        || { echo "could not list $r branches — refusing to wave a partial fleet" >&2; exit 2; }
      branches=$(printf '%s\n' "$branches" | grep -E '^main' || true)
    else
      branches=$def
    fi
    # A branch is a target when it carries claude.yml OR dependabot-validate.yml: the stub-only pairs
    # hold nothing but the three Dependabot stubs, and skipping them would strand their pins one tag
    # behind for ever — fleet-pin-audit.sh --stale could never read clean. The second probe runs only
    # when the first 404s, and plan_and_push skips the files a target does not have.
    for b in $branches; do
      if api "repos/$ORG/$r/contents/.github/workflows/claude.yml?ref=$b" --jq .sha >/dev/null 2>&1 \
         || api "repos/$ORG/$r/contents/.github/workflows/dependabot-validate.yml?ref=$b" --jq .sha >/dev/null 2>&1; then
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
  existing=$(api "repos/$ORG/$repo/contents/.github/workflows?ref=$branch" --jq '.[].path') \
    || { echo "  $repo@$branch: cannot list .github/workflows" >&2; exit 3; }
  # An empty listing here would make every grep below miss and the target report "(no changes)" —
  # a repo silently dropped from the wave. Discovery proved it carries at least one kit file, so
  # empty is a lie.
  [ -n "$existing" ] || { echo "  $repo@$branch: empty .github/workflows listing" >&2; exit 3; }
  # .github/ itself, for the PR template — its own assignment, so a failure here cannot hide
  # behind the workflows listing above (errexit is off inside an assignment's substitution).
  dotgithub=$(api "repos/$ORG/$repo/contents/.github?ref=$branch" --jq '.[] | select(.type == "file") | .path') \
    || { echo "  $repo@$branch: cannot list .github" >&2; exit 3; }
  existing="$existing"$'\n'"$dotgithub"

  for f in "${FULL_FILES[@]}"; do
    grep -qxF "$(dest "$f")" <<<"$existing" || continue
    # errexit would abort on the sed's missing source anyway; this fails with a clear message and
    # exit 3 before the network fetch. If the kit dropped it on purpose it belongs in DELETE_FILES.
    [ -f "$KIT/$f" ] \
      || { echo "  $repo@$branch $f: not in the kit any more — move it to DELETE_FILES?" >&2; exit 3; }
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
[ -n "$TARGETS" ] || { echo "no targets discovered — refusing to call that a clean fleet" >&2; exit 2; }
n=0
while read -r repo branch; do
  [ -n "$repo" ] || continue
  echo "== $repo@$branch"; plan_and_push "$repo" "$branch"; n=$((n+1))
done <<<"$TARGETS"
echo "targets: $n"
