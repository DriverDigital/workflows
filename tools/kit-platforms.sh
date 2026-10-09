# shellcheck shell=bash
# tools/kit-platforms.sh — sourced by fleet-wave.sh and fleet-pin-audit.sh.
#
# Which repos get the kit, and which part of it, is set by GitHub topics on each repo:
#   driver-kit                  the repo takes the kit at all; the wave targets nothing without it,
#                               so a stale repo stays untouched without having to be archived
#   shopify-theme / vercel-site its hosting platform, which adds that platform's files
#   / wordpress-site            (WordPress has none yet: those repos take the shared kit only)
# A platform's files never reach a repo of the other platform or of none: the wave refuses to write
# one there and the audit reports one found there, as it does kit files on a repo without driver-kit.
KIT_TOPIC=driver-kit
SHOPIFY_FILES=(shopify-tool-smoke.yml shopify-theme.yml)
VERCEL_FILES=(vercel-deploy.yml)

# The platform a kit file belongs to, or nothing for the shared kit.
file_platform() {
  case " ${SHOPIFY_FILES[*]} " in *" $1 "*) echo shopify; return ;; esac
  case " ${VERCEL_FILES[*]} " in *" $1 "*) echo vercel ;; esac
}

# Whether a repo takes the kit, from its topics (space- or newline-separated).
topics_enrolled() {
  local t
  for t in $1; do [ "$t" = "$KIT_TOPIC" ] && return 0; done
  return 1
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

# Which templates/github/dependabot/<variant>.yml a repo takes as its .github/dependabot.yml: a repo
# with its own exceptions by name, otherwise npm when the branch root holds a package.json (1), else
# actions when it has .github/workflows (1), else none: Dependabot errors daily on an empty ecosystem.
dependabot_variant() {  # repo has_root_package_json has_workflows
  case "$1" in
    driver-agents|vite-plugin-shopify-clean) echo "$1" ;;
    *) if [ "$2" = 1 ]; then echo npm; elif [ "$3" = 1 ]; then echo actions; else echo none; fi ;;
  esac
}
