#!/usr/bin/env bash
# fleet-pin-audit.sh — one-command drift detector for the central-workflow pins.
#
# Scans every non-archived DriverDigital repo's .github/workflows/ (default
# branch, plus every main* branch of Palmers — the kit is installed per country
# branch there) for `uses: DriverDigital/workflows/...@SHA` caller-stub pins,
# prints one line per pin, and summarizes pins by SHA against the latest tag.
#
# Dependabot does NOT bump these reusable-workflow pins in practice (verified
# 2026-07-16: zero such PRs fleet-wide, even in repos with a github-actions
# block) — repins happen as manual waves, and this script is how drift gets
# seen between waves. Needs: gh (authenticated), org read access.
#
# Usage: tools/fleet-pin-audit.sh            # full report
#        tools/fleet-pin-audit.sh --stale    # only pins not at the latest tag
set -u

ORG="${ORG:-DriverDigital}"
LATEST="$(gh api "repos/$ORG/workflows/tags" --jq '.[0] | "\(.name) \(.commit.sha)"')"
LATEST_TAG="${LATEST%% *}"; LATEST_SHA="${LATEST#* }"; LATEST_SHA8="${LATEST_SHA:0:8}"

scan_ref() {  # repo ref
  local repo="$1" ref="$2" files f raw
  files="$(gh api "repos/$ORG/$repo/contents/.github/workflows?ref=$ref" --jq '.[].name' 2>/dev/null)" || return 0
  for f in $files; do
    raw="$(gh api "repos/$ORG/$repo/contents/.github/workflows/$f?ref=$ref" -H 'Accept: application/vnd.github.raw' 2>/dev/null)" || continue
    printf '%s' "$raw" | grep -o "$ORG/workflows/.github/workflows/[^@]*@[0-9a-f]*" \
      | sed "s|$ORG/workflows/.github/workflows/||; s|@\([0-9a-f]\{8\}\)[0-9a-f]*|@\1|" \
      | while read -r line; do echo "$repo@$ref $f $line"; done
  done
}

report="$(
  gh repo list "$ORG" --limit 100 --no-archived --json name,defaultBranchRef \
    --jq '.[] | "\(.name) \(.defaultBranchRef.name)"' | while read -r repo def; do
    scan_ref "$repo" "$def"
    if [ "$repo" = "Palmers" ]; then
      gh api "repos/$ORG/Palmers/branches?per_page=100" --jq '.[].name' 2>/dev/null \
        | grep '^main' | grep -v "^$def\$" | while read -r b; do scan_ref "$repo" "$b"; done
    fi
  done | sort
)"

if [ "${1:-}" = "--stale" ]; then
  printf '%s\n' "$report" | grep -v "@$LATEST_SHA8" || echo "(no stale pins — fleet uniform at $LATEST_TAG)"
else
  printf '%s\n' "$report"
fi
echo
echo "latest: $LATEST_TAG ($LATEST_SHA8) — pins by SHA:"
printf '%s\n' "$report" | sed 's/.*@//' | sort | uniq -c | sort -rn
