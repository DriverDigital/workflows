# shellcheck shell=bash
# tools/kit-platforms.sh — sourced by fleet-wave.sh and fleet-pin-audit.sh.
#
# Which repos get the kit, and which part of it, is set by GitHub topics and visibility:
#   driver-kit                  the repo takes the kit at all; the wave targets nothing without it,
#                               so a stale repo stays untouched without having to be archived
#   shopify-theme / vercel-site its hosting platform, which adds that platform's files
#   / wordpress-site            (Vercel and WordPress have only their .node-version: see
#                               node_version_source)
#   agents-pipeline             the repo is on the Bonsai ticket pipeline: it takes the implementer
#   maintenance-paused          no maintenance agreement: the repo gets no Dependabot (topics_paused)
# A repo's tier is the most of the kit it may carry: public repos the standards only, private repos
# the private files too, private repos with agents-pipeline everything (repo_tier, file_tier).
# A file above a repo's tier, or a platform file on a repo of the other platform or of none, never
# reaches it: the wave refuses to write one there and the audit reports one found there, as it does
# kit files on a repo without driver-kit.
KIT_TOPIC=driver-kit
PIPELINE_TOPIC=agents-pipeline
PAUSED_TOPIC=maintenance-paused
PRIVATE_FILES=(dependabot-report.yml dependabot-keep-current.yml shopify-theme.yml)
PIPELINE_FILES=(claude.yml shopify-tool-smoke.yml pr-bonsai-link.yml pull_request_template.md)
SHOPIFY_FILES=(shopify-tool-smoke.yml shopify-theme.yml)
# Macroscope check-run agents reach every repo from driver-agents, Macroscope's policy repo, so the
# kit carries none. A repo's own copy at the same path would override the policy file: the wave
# deletes these from .macroscope/check-run-agents/ on Shopify repos, and the audit reports one found.
RETIRED_AGENT_FILES=(figma-design-fidelity.md figma-design-fidelity-shopify.md)

# The platform a kit file belongs to, or nothing for the shared kit.
file_platform() {
  case " ${SHOPIFY_FILES[*]} " in *" $1 "*) echo shopify ;; esac
}

agent_platform() { [ "$1" = shopify ]; }
is_agent() { case " ${RETIRED_AGENT_FILES[*]} " in *" $1 "*) return 0 ;; esac; return 1; }

# Whether a repo takes the kit, from its topics (space- or newline-separated).
topics_enrolled() {
  local t
  for t in $1; do [ "$t" = "$KIT_TOPIC" ] && return 0; done
  return 1
}

# Whether a repo is maintenance-paused. The wave deletes a paused repo's .github/dependabot.yml and
# never writes one, so Dependabot opens no PRs there; the audit reports one found. Removing the topic
# brings the file back with the next wave. A paused repo that is not the only home of a live site's
# code is archived instead, which the wave and the audit skip (docs/branch-model.md).
topics_paused() {
  local t
  for t in $1; do [ "$t" = "$PAUSED_TOPIC" ] && return 0; done
  return 1
}

# A repo's tier from its visibility (isPrivate: true or false) and topics: public, private or pipeline.
# A public repo is public whatever its topics say; the wave refuses one that carries agents-pipeline.
repo_tier() {  # is_private topics
  local t
  [ "$1" = true ] || { echo public; return; }
  for t in $2; do [ "$t" = "$PIPELINE_TOPIC" ] && { echo pipeline; return; }; done
  echo private
}

# The tier a kit file needs: standards (every kit repo), private or pipeline.
file_tier() {
  case " ${PIPELINE_FILES[*]} " in *" $1 "*) echo pipeline; return ;; esac
  case " ${PRIVATE_FILES[*]} " in *" $1 "*) echo private; return ;; esac
  echo standards
}

tier_allows() {  # repo_tier file_tier
  case "$1:$2" in *:standards|private:private|pipeline:*) return 0 ;; esac
  return 1
}

# Whether the wave adds a kit file where the branch lacks it (once tier and platform allow it), or
# only refreshes a copy already there. The platform stubs and the store smoke test need per-repo
# secrets set up first, so they arrive with the repo's cutover; .node-version needs a platform.
wave_adds() {  # file node_version_source
  case "$1" in
    shopify-theme.yml|shopify-tool-smoke.yml) return 1 ;;
    node-version) [ -n "$2" ] ;;
    *) return 0 ;;
  esac
}

# A repo's platform from its topics (space- or newline-separated): shopify, vercel, wordpress, none,
# or several — which callers treat as an error, since no kit file could be checked against it.
topics_platform() {
  local found="" n=0 t
  for t in $1; do
    case "$t" in
      shopify-theme) found=shopify; n=$((n + 1)) ;;
      vercel-site) found=vercel; n=$((n + 1)) ;;
      wordpress-site) found=wordpress; n=$((n + 1)) ;;
    esac
  done
  case $n in 0) echo none ;; 1) echo "$found" ;; *) echo several ;; esac
}

# Which templates/github/node-version/<platform> a repo takes as its root .node-version, or nothing:
# one per platform, so each can change major on its own. A repo with no platform takes none.
node_version_source() {  # platform
  case "$1" in shopify|vercel|wordpress) echo "node-version/$1" ;; esac
}

# Which templates/github/dependabot/<variant>.yml a repo takes as its .github/dependabot.yml: a repo
# with its own exceptions by name, otherwise npm when the branch root holds a package.json (1), else
# actions, since every kit branch carries at least lint.yml once waved.
dependabot_variant() {  # repo has_root_package_json
  case "$1" in
    driver-agents|vite-plugin-shopify-clean) echo "$1" ;;
    *) if [ "$2" = 1 ]; then echo npm; else echo actions; fi ;;
  esac
}
