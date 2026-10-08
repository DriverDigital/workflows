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
#      text, and a full-workflow copy of what should be a thin stub has no `uses:` line at all
#      — so a pin grep sees none of them. Only trailing blank lines are normalized away (see
#      `kit_normalize` for why), and claude-settings.json is compared on its attribution keys
#      alone; anything else that differs is drift.
#
# Scans every non-archived DriverDigital repo's .github/ and .claude/settings.json (default branch,
# plus every main* branch of Palmers — the kit is installed per country branch there). Kit files on
# a repo without the driver-kit topic are listed apart as unenrolled and never count as drift; a
# platform file on a repo whose topic names another platform, or none, is drift (tools/kit-platforms.sh).
#
# Dependabot does bump these pins when a repo has a github-actions block and the tag lands before
# the wave (Palmers #93 / vite-plugin-shopify-clean #72, 2026-07-02) — in practice the wave repins
# within minutes of every tag, so it rarely gets the chance; see docs/fleet-operations.md. This
# script is how drift gets seen between waves. Needs: gh (authenticated), org read access, jq.
#
# Usage: tools/fleet-pin-audit.sh            # full report
#        tools/fleet-pin-audit.sh --stale    # only what has drifted
#
# Exits non-zero when anything enrolled has drifted, so a wave can gate on it.
set -u

ORG="${ORG:-DriverDigital}"
KIT="$(cd "$(dirname "$0")/../templates/github" && pwd)"
# shellcheck source=tools/kit-platforms.sh
. "$(dirname "$0")/kit-platforms.sh"

# Newest vX.Y.Z by semver, not the API's first row: the tags endpoint orders by ref name, which
# GitHub does not document, so a non-release tag could land at .[0] and every guard below would
# measure against it. --jq runs per page under --paginate, so the max is taken after, in sort -V.
# pipefail (scoped to the substitution): a later page that fails must not leave a partial list
# whose max reads as the latest release, and no release tag at all is not a fleet to measure.
LATEST="$(set -o pipefail; gh api "repos/$ORG/workflows/tags" --paginate --jq '.[] | select(.name | test("^v(0|[1-9][0-9]*)(\\.(0|[1-9][0-9]*)){2}$")) | "\(.name) \(.commit.sha)"' | sort -V | tail -1)" \
  || { echo "FATAL: could not list $ORG/workflows tags — this run proves nothing." >&2; exit 2; }
[ -n "$LATEST" ] || { echo "FATAL: no vX.Y.Z tag on $ORG/workflows — nothing to measure against." >&2; exit 2; }
LATEST_TAG="${LATEST%% *}"; LATEST_SHA="${LATEST#* }"; LATEST_SHA8="${LATEST_SHA:0:8}"

# One normalization for every file, deliberate (claude-settings.json is compared on its attribution
# keys alone, in content_row). Everything else that differs is reported — third-party
# action refs included: a consumer repo whose Dependabot moved `actions/checkout@v7` to `@v8` ahead of
# the kit is drift worth seeing, since it means the kit is behind, not that the repo is wrong. (The
# store handle needed a second one until v1.17.0 moved it into a repository variable.)
#
#   Trailing blank lines and the final newline. Two stub-rails-only pairs (Team-Laird@develop,
#      The-Gathery@develop) were waved without a final newline and are
#      otherwise byte-identical. That is not drift anyone can act on, and a detector that reports
#      permanent red rows is a detector nobody reads. Internal blank lines ARE still compared —
#      awk buffers blanks and only emits them once a non-blank line follows.
kit_normalize() {
  awk '/^[[:space:]]*$/ { blank++; next } { while (blank-- > 0) print ""; blank = 0; print }'
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

content_row() {  # repo ref file — $TMP/raw holds the deployed bytes
  local repo="$1" ref="$2" f="$3"
  if [ "$f" = claude-settings.json ]; then
    # The repo owns the rest of .claude/settings.json; the wave merges in only the kit keys.
    jq -S .attribution < "$TMP/raw" > "$TMP/deployed" 2>/dev/null || echo "invalid JSON" > "$TMP/deployed"
    jq -S .attribution < "$KIT/$f"  > "$TMP/kit"
  else
    kit_normalize < "$TMP/raw"  > "$TMP/deployed"
    kit_normalize < "$KIT/$f"   > "$TMP/kit"
  fi
  if command diff -q "$TMP/deployed" "$TMP/kit" >/dev/null 2>&1; then
    echo "CONTENT $repo@$ref $f ok"
  else
    echo "CONTENT $repo@$ref $f DRIFT $(command diff "$TMP/deployed" "$TMP/kit" \
      | grep -c '^[<>]') lines differ"
  fi
}

scan_ref() {  # repo ref platform
  local repo="$1" ref="$2" plat="$3" files f fp
  files="$(gh api "repos/$ORG/$repo/contents/.github/workflows?ref=$ref" --jq '.[].name' 2>/dev/null)" || return 0
  for f in $files; do
    # Straight to a file, never a variable: `$(...)` strips ALL trailing newlines, so a deployed
    # file differing from the kit only in trailing blank lines would compare equal and report `ok`.
    # A drift detector may not have a shape of drift it cannot see.
    gh api "repos/$ORG/$repo/contents/.github/workflows/$f?ref=$ref" \
      -H 'Accept: application/vnd.github.raw' > "$TMP/raw" 2>/dev/null || continue

    # 2. PINS (an unenrolled repo's are listed with its files below, not counted as stale)
    [ "$plat" = unenrolled ] || grep -o "$ORG/workflows/.github/workflows/[^@]*@[0-9a-f]*" "$TMP/raw" \
      | sed "s|$ORG/workflows/.github/workflows/||; s|@\([0-9a-f]\{8\}\)[0-9a-f]*|@\1|" \
      | while read -r line; do echo "PIN $repo@$ref $f $line"; done

    # 3. CONTENT — only for files the kit actually ships. A platform file on a repo whose topic
    # names another platform (or none) is drift whatever its bytes say; the wave refuses to touch it.
    [ -f "$KIT/$f" ] || continue
    if [ "$plat" = unenrolled ]; then
      echo "UNENROLLED $repo@$ref $f"
      continue
    fi
    fp="$(file_platform "$f")"
    if [ -n "$fp" ] && [ "$fp" != "$plat" ]; then
      echo "CONTENT $repo@$ref $f DRIFT platform: a $fp file, repo topic says $plat"
      continue
    fi
    content_row "$repo" "$ref" "$f"
  done
  # The install-beside-claude.yml checks below are about what the wave would add; it adds nothing to
  # an unenrolled repo, whose kit files are already reported above.
  [ "$plat" = unenrolled ] && return 0
  # The wave installs pr-bonsai-link.yml and claude-standards.md wherever claude.yml is, so their
  # absence there is drift (the standards file is probed at .github/ below).
  if grep -qx claude.yml <<<"$files" && ! grep -qx pr-bonsai-link.yml <<<"$files"; then
    echo "CONTENT $repo@$ref pr-bonsai-link.yml DRIFT missing"
  fi
  # The kit files outside .github/workflows/: the PR template (waved since v1.15.0) and the house
  # standards. Presence comes from the directory listing, as above, so a failed API call skips the
  # file rather than reading as "missing".
  local dotgithub
  dotgithub="$(gh api "repos/$ORG/$repo/contents/.github?ref=$ref" --jq '.[].name' 2>/dev/null)" || dotgithub=""
  for f in pull_request_template.md claude-standards.md; do
    if grep -qx "$f" <<<"$dotgithub"; then
      gh api "repos/$ORG/$repo/contents/.github/$f?ref=$ref" \
        -H 'Accept: application/vnd.github.raw' > "$TMP/raw" 2>/dev/null || continue
      content_row "$repo" "$ref" "$f"
    elif [ -n "$dotgithub" ] && [ "$f" = claude-standards.md ] && grep -qx claude.yml <<<"$files"; then
      echo "CONTENT $repo@$ref $f DRIFT missing"
    fi
  done
  # The shared Claude Code project settings at .claude/settings.json, installed beside claude.yml.
  # Missing is reported only when both listings succeeded; a failed call skips the check.
  local rootdirs dotclaude=""
  rootdirs="$(gh api "repos/$ORG/$repo/contents?ref=$ref" --jq '.[] | select(.type == "dir") | .name' 2>/dev/null)" || return 0
  if grep -qx .claude <<<"$rootdirs"; then
    dotclaude="$(gh api "repos/$ORG/$repo/contents/.claude?ref=$ref" --jq '.[].name' 2>/dev/null)" || return 0
  fi
  if grep -qx settings.json <<<"$dotclaude"; then
    gh api "repos/$ORG/$repo/contents/.claude/settings.json?ref=$ref" \
      -H 'Accept: application/vnd.github.raw' > "$TMP/raw" 2>/dev/null || return 0
    content_row "$repo" "$ref" claude-settings.json
  elif grep -qx claude.yml <<<"$files"; then
    echo "CONTENT $repo@$ref claude-settings.json DRIFT missing"
  fi
}

# Enumerate the fleet OUTSIDE the report subshell — a failure here has to be able to kill the run.
# `--limit 200` against ~58 non-archived repos today; the old 100 was a silent truncation cliff.
repos="$(gh repo list "$ORG" --limit 200 --no-archived --json name,defaultBranchRef,repositoryTopics \
           --jq '.[] | "\(.name) \(.defaultBranchRef.name) \([(.repositoryTopics // [])[].name] | join(","))"')" || repos=""
if [ -z "$repos" ]; then
  echo "FATAL: could not enumerate $ORG repos (gh failed, or auth/network is down)." >&2
  echo "This run proves NOTHING. An empty scan is not a clean fleet — do not read it as one." >&2
  exit 2
fi

report="$(
  printf '%s\n' "$repos" | while read -r repo def topics; do
    # Skip the kit repo itself: its .github/workflows/ holds the REUSABLES, which share basenames
    # with the stubs that call them (dependabot-validate.yml is a reusable here and a thin stub in
    # the kit), so a content compare against templates/ would report a phantom drift for every
    # caller stub, plus lint.yml, whose kit copy is a trimmed version of the CI file of
    # the same name here. NB: no apostrophes in comments inside this $( ) — bash opens a quote on
    # one even in a comment, and the parse error it produces points at EOF, not at the line.
    [ "$repo" = "workflows" ] && continue
    plat="$(topics_platform "${topics//,/ }")"
    # A repo without the driver-kit topic is still scanned, and its kit workflow files are listed
    # apart: the wave keeps them current no longer, but a dormant repo may keep them until it is
    # archived, so they never count as drift.
    topics_enrolled "${topics//,/ }" || plat="unenrolled"
    scan_ref "$repo" "$def" "$plat"
    if [ "$repo" = "Palmers" ]; then
      gh api "repos/$ORG/Palmers/branches?per_page=100" --jq '.[].name' 2>/dev/null \
        | grep '^main' | grep -v "^$def\$" | while read -r b; do scan_ref "$repo" "$b" "$plat"; done
    fi
  done | sort
)"

pins="$(printf '%s\n' "$report" | grep '^PIN ' | sed 's/^PIN //')"
stale="$(printf '%s\n' "$pins" | grep -v "@$LATEST_SHA8")"
content="$(printf '%s\n' "$report" | grep '^CONTENT ' | sed 's/^CONTENT //')"
unenrolled="$(printf '%s\n' "$report" | grep '^UNENROLLED ' | sed 's/^UNENROLLED //')"
drift="$(printf '%s\n' "$content" | grep ' DRIFT ')"

# Every kit repo@branch pair carries at least one caller stub, so zero pins fleet-wide means the
# scan read nothing — rate limiting, a revoked token, an org rename. Without this the run falls
# straight through to "(converged)" and exit 0, which is the exact failure this whole tool exists
# to stop: a clean report that proves nothing.
if [ -z "$pins" ]; then
  echo "FATAL: zero caller-stub pins found across $(printf '%s\n' "$repos" | grep -c .) repos." >&2
  echo "The fleet always carries some, so the scan failed to read, or no repo carries the $KIT_TOPIC" >&2
  echo "topic yet — this is not a clean fleet." >&2
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
if [ -n "$unenrolled" ]; then
  echo
  echo "unenrolled (kit workflow files on repos without the $KIT_TOPIC topic; not waved, not drift):"
  printf '  %s\n' "$unenrolled"
fi

[ -z "$reference$stale$drift" ]
