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
#      `uses:` line at all — so a pin grep sees none of them. Only state the kit documents as
#      per-repo is normalized away (`SHOPIFY_STORE_NAME`); anything else that differs is drift.
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

# The one difference a correctly-waved repo is SUPPOSED to have: its own store handle, which the
# kit ships empty. Everything else — third-party action pins included — is reported. A consumer
# repo whose Dependabot bumped `actions/checkout` past the kit's pin is drift worth seeing: it
# means the kit is behind, not that the repo is wrong.
kit_normalize() { sed 's/^\( *SHOPIFY_STORE_NAME:\).*/\1 <per-repo>/'; }

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

scan_ref() {  # repo ref
  local repo="$1" ref="$2" files f raw local_kit deployed
  files="$(gh api "repos/$ORG/$repo/contents/.github/workflows?ref=$ref" --jq '.[].name' 2>/dev/null)" || return 0
  for f in $files; do
    raw="$(gh api "repos/$ORG/$repo/contents/.github/workflows/$f?ref=$ref" -H 'Accept: application/vnd.github.raw' 2>/dev/null)" || continue

    # 2. PINS
    printf '%s' "$raw" | grep -o "$ORG/workflows/.github/workflows/[^@]*@[0-9a-f]*" \
      | sed "s|$ORG/workflows/.github/workflows/||; s|@\([0-9a-f]\{8\}\)[0-9a-f]*|@\1|" \
      | while read -r line; do echo "PIN $repo@$ref $f $line"; done

    # 3. CONTENT — only for files the kit actually ships.
    [ -f "$KIT/$f" ] || continue
    deployed="$(printf '%s' "$raw" | kit_normalize)"
    local_kit="$(kit_normalize < "$KIT/$f")"
    if [ "$deployed" = "$local_kit" ]; then
      echo "CONTENT $repo@$ref $f ok"
    else
      echo "CONTENT $repo@$ref $f DRIFT $(command diff \
        <(printf '%s\n' "$deployed") <(printf '%s\n' "$local_kit") | grep -c '^[<>]') lines differ"
    fi
  done
}

report="$(
  gh repo list "$ORG" --limit 100 --no-archived --json name,defaultBranchRef \
    --jq '.[] | "\(.name) \(.defaultBranchRef.name)"' | while read -r repo def; do
    # Skip the kit repo itself: its .github/workflows/ holds the REUSABLES, which share basenames
    # with the stubs that call them (pr-first-review.yml is a 200-line reusable here and a 25-line
    # stub in the kit), so a content compare against templates/ would report six phantom drifts.
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
