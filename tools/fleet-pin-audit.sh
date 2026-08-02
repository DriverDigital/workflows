#!/usr/bin/env bash
# fleet-pin-audit.sh — one-command drift detector for the central-workflow kit.
#
# Three checks, because a pin line alone never proved the fleet was current:
#
#   1. REFERENCE — every `uses:` pin in templates/github/*.yml equals the latest tag's SHA. Checks
#      2 and 3 measure the fleet against `templates/`, so a stale reference makes both of them lie.
#      That is exactly how the v1.9.0 gap survived a day: the wave repinned the fleet to `a54c91e`
#      while the kit's own stubs still said `80c35fe`, and an audit that compared deployed pins to
#      the latest *tag* — never to `templates/` — called the fleet uniform the whole time.
#   2. PINS — every deployed caller stub's `uses: DriverDigital/workflows/...@SHA` vs that tag.
#   3. CONTENT — the whole waved file vs its templates/github/ source. The pin is one line of it:
#      `DRIVER_AGENTS_REF` is a raw SHA in an `env:` block, the implementer's system prompt is just
#      text, and an unconverted 190-line copy of a workflow that is now a 66-line stub has no
#      `uses:` line at all — so a pin grep sees none of them. Exactly two things are normalized
#      away — the per-repo store handle and trailing blank lines (see `kit_normalize` for why);
#      anything else that differs is drift.
#
# Scans every non-archived DriverDigital repo's .github/workflows/ (default branch, plus every
# main* branch of Palmers — the kit is installed per country branch there).
#
# Dependabot does NOT bump these reusable-workflow pins in practice (verified 2026-07-16: zero such
# PRs fleet-wide, even in repos with a github-actions block) — repins happen as manual waves, and
# this script is how drift gets seen between waves. Needs: gh (authenticated), org read access.
#
# Usage: tools/fleet-pin-audit.sh            # full report
#        tools/fleet-pin-audit.sh --stale    # only what has drifted
#
# Exits non-zero when anything has drifted, so a wave can gate on it.
set -u

ORG="${ORG:-DriverDigital}"
KIT="$(cd "$(dirname "$0")/../templates/github" && pwd)"

LATEST="$(gh api "repos/$ORG/workflows/tags" --jq '.[0] | "\(.name) \(.commit.sha)"')"
LATEST_TAG="${LATEST%% *}"; LATEST_SHA="${LATEST#* }"; LATEST_SHA8="${LATEST_SHA:0:8}"

# EXACTLY TWO normalizations, both deliberate. Everything else that differs is reported — third-party
# action pins included: a consumer repo whose Dependabot bumped `actions/checkout` past the kit's pin
# is drift worth seeing, since it means the kit is behind, not that the repo is wrong.
#
#   1. SHOPIFY_STORE_NAME — the one difference a correctly-waved repo is SUPPOSED to have. The kit
#      ships it empty; Avara carries "avara". Anchored to a line that STARTS with the key, so the ten
#      other mentions per file (comments, shell) still compare normally.
#   2. Trailing blank lines and the final newline. Three stub-rails-only pairs (Team-Laird@develop,
#      The-Gathery@develop, driver-bonsai-mcp@main) were waved without a final newline and are
#      otherwise byte-identical. That is not drift anyone can act on, and a detector that reports
#      nine permanent red rows is a detector nobody reads. Internal blank lines ARE still compared —
#      awk buffers blanks and only emits them once a non-blank line follows.
kit_normalize() {
  sed 's/^\( *SHOPIFY_STORE_NAME:\).*/\1 <per-repo>/' \
    | awk '/^[[:space:]]*$/ { blank++; next } { while (blank-- > 0) print ""; blank = 0; print }'
}

# 1. REFERENCE — templates/ against the latest tag.
reference="$(
  for t in "$KIT"/*.yml; do
    grep -o "$ORG/workflows/\.github/workflows/[^@]*@[0-9a-f]\{40\}" "$t" | sed 's/.*@//' \
      | while read -r sha; do
          [ "$sha" = "$LATEST_SHA" ] \
            || echo "templates/github/$(basename "$t") pins @${sha:0:8} — $LATEST_TAG is $LATEST_SHA8"
        done
  done
)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

scan_ref() {  # repo ref
  local repo="$1" ref="$2" files f
  files="$(gh api "repos/$ORG/$repo/contents/.github/workflows?ref=$ref" --jq '.[].name' 2>/dev/null)" || return 0
  for f in $files; do
    # Straight to a file, never a variable: `$(...)` strips ALL trailing newlines, so a deployed
    # file differing from the kit only in trailing blank lines would compare equal and report `ok`.
    # A drift detector may not have a shape of drift it cannot see.
    gh api "repos/$ORG/$repo/contents/.github/workflows/$f?ref=$ref" \
      -H 'Accept: application/vnd.github.raw' > "$TMP/raw" 2>/dev/null || continue

    # 2. PINS
    grep -o "$ORG/workflows/.github/workflows/[^@]*@[0-9a-f]*" "$TMP/raw" \
      | sed "s|$ORG/workflows/.github/workflows/||; s|@\([0-9a-f]\{8\}\)[0-9a-f]*|@\1|" \
      | while read -r line; do echo "PIN $repo@$ref $f $line"; done

    # 3. CONTENT — only for files the kit actually ships.
    [ -f "$KIT/$f" ] || continue
    kit_normalize < "$TMP/raw"  > "$TMP/deployed"
    kit_normalize < "$KIT/$f"   > "$TMP/kit"
    if command diff -q "$TMP/deployed" "$TMP/kit" >/dev/null 2>&1; then
      echo "CONTENT $repo@$ref $f ok"
    else
      echo "CONTENT $repo@$ref $f DRIFT $(command diff "$TMP/deployed" "$TMP/kit" \
        | grep -c '^[<>]') lines differ"
    fi
  done
}

# Enumerate the fleet OUTSIDE the report subshell — a failure here has to be able to kill the run.
# `--limit 200` against ~58 non-archived repos today; the old 100 was a silent truncation cliff.
repos="$(gh repo list "$ORG" --limit 200 --no-archived --json name,defaultBranchRef \
           --jq '.[] | "\(.name) \(.defaultBranchRef.name)"')" || repos=""
if [ -z "$repos" ]; then
  echo "FATAL: could not enumerate $ORG repos (gh failed, or auth/network is down)." >&2
  echo "This run proves NOTHING. An empty scan is not a clean fleet — do not read it as one." >&2
  exit 2
fi

report="$(
  printf '%s\n' "$repos" | while read -r repo def; do
    # Skip the kit repo itself: its .github/workflows/ holds the REUSABLES, which share basenames
    # with the stubs that call them (pr-first-review.yml is a 200-line reusable here and a 25-line
    # stub in the kit), so a content compare against templates/ would report seven phantom drifts:
    # the six stubs, plus lint.yml, whose kit copy is a trimmed version of the CI file of the same
    # name here. NB: no apostrophes in comments inside this $( ) — bash opens a quote on one even
    # in a comment, and the parse error it produces points at EOF, not at the line.
    [ "$repo" = "workflows" ] && continue
    scan_ref "$repo" "$def"
    if [ "$repo" = "Palmers" ]; then
      gh api "repos/$ORG/Palmers/branches?per_page=100" --jq '.[].name' 2>/dev/null \
        | grep '^main' | grep -v "^$def\$" | while read -r b; do scan_ref "$repo" "$b"; done
    fi
  done | sort
)"

pins="$(printf '%s\n' "$report" | grep '^PIN ' | sed 's/^PIN //')"
stale="$(printf '%s\n' "$pins" | grep -v "@$LATEST_SHA8")"
content="$(printf '%s\n' "$report" | grep '^CONTENT ' | sed 's/^CONTENT //')"
drift="$(printf '%s\n' "$content" | grep ' DRIFT ')"

# Every kit repo@branch pair carries at least one caller stub, so zero pins fleet-wide means the
# scan read nothing — rate limiting, a revoked token, an org rename. Without this the run falls
# straight through to "(converged)" and exit 0, which is the exact failure this whole tool exists
# to stop: a clean report that proves nothing.
if [ -z "$pins" ]; then
  echo "FATAL: zero caller-stub pins found across $(printf '%s\n' "$repos" | grep -c .) repos." >&2
  echo "The fleet always carries some, so the scan failed to read — this is not a clean fleet." >&2
  exit 2
fi

if [ "${1:-}" = "--stale" ]; then
  [ -n "$reference" ] && { echo "reference drift (templates/ is not at $LATEST_TAG):"; printf '%s\n' "$reference"; echo; }
  [ -n "$stale" ] && { echo "stale pins:"; printf '%s\n' "$stale"; echo; }
  [ -n "$drift" ] && { echo "content drift:"; printf '%s\n' "$drift"; echo; }
  [ -n "$reference$stale$drift" ] || echo "(converged — templates/, pins, and waved content all at $LATEST_TAG)"
else
  printf '%s\n' "$pins"
  echo
  printf '%s\n' "$content"
fi

echo
if [ -n "$reference" ]; then
  echo "REFERENCE DRIFT — templates/ pins disagree with $LATEST_TAG, so every line above is measured"
  echo "against a stale baseline. Fix step 2 of the README's release order before trusting this run:"
  printf '  %s\n' "$reference"
else
  echo "reference: templates/github/ pins all at $LATEST_TAG ($LATEST_SHA8)"
fi
echo "latest: $LATEST_TAG ($LATEST_SHA8) — pins by SHA:"
printf '%s\n' "$pins" | sed 's/.*@//' | sort | uniq -c | sort -rn
echo "content: $(printf '%s\n' "$content" | grep -c ' ok$') match templates/, $(printf '%s\n' "$content" | grep -c ' DRIFT ') drifted"

[ -z "$reference$stale$drift" ]
