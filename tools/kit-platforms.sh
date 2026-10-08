# shellcheck shell=bash
# tools/kit-platforms.sh — sourced by fleet-wave.sh and fleet-pin-audit.sh.
#
# The kit has a shared part and one part per hosting platform. A repo declares its platform with a
# GitHub topic, shopify-theme or vercel-site, and a platform's files never reach a repo of the other
# platform or of none: the wave refuses to write one there and the audit reports one found there.
SHOPIFY_FILES=(shopify-tool-smoke.yml shopify-theme.yml)
VERCEL_FILES=(vercel-deploy.yml)

# The platform a kit file belongs to, or nothing for the shared kit.
file_platform() {
  case " ${SHOPIFY_FILES[*]} " in *" $1 "*) echo shopify; return ;; esac
  case " ${VERCEL_FILES[*]} " in *" $1 "*) echo vercel ;; esac
}

# A repo's platform from its topics (space- or newline-separated): shopify, vercel, none, or both —
# which callers treat as an error, since no kit file could be checked against it.
topics_platform() {
  local s=0 v=0 t
  for t in $1; do
    [ "$t" = shopify-theme ] && s=1
    [ "$t" = vercel-site ] && v=1
  done
  case "$s$v" in 10) echo shopify ;; 01) echo vercel ;; 11) echo both ;; *) echo none ;; esac
}
