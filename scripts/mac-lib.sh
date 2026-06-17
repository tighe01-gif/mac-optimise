#!/usr/bin/env bash
# Shared helpers for Mac Optimise scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)"

# shellcheck source=/dev/null
[[ -f "${ROOT}/config/defaults.env" ]] && source "${ROOT}/config/defaults.env"
# shellcheck source=/dev/null
[[ -f "${ROOT}/config/local.env" ]] && source "${ROOT}/config/local.env"
# shellcheck source=/dev/null
[[ -f "${ROOT}/config/dj-protected-paths.env" ]] && source "${ROOT}/config/dj-protected-paths.env"

export PATH="/usr/local/bin:/opt/homebrew/bin:${PATH:-}"

# rekordbox, DJ.Studio, MIXO, Mixed In Key — never touch (see config/dj-protected-paths.env).
is_dj_protected_path() {
  local p="$1" frag root
  if [[ -n "${DJ_PROTECT_FRAGMENTS:-}" ]]; then
    for frag in "${DJ_PROTECT_FRAGMENTS[@]}"; do
      [[ -n "$frag" && "$p" == *"$frag"* ]] && return 0
    done
  fi
  if [[ -n "${DJ_PROTECT_ROOTS:-}" ]]; then
    for root in "${DJ_PROTECT_ROOTS[@]}"; do
      [[ -n "$root" && "$p" == "$root"* ]] && return 0
    done
  fi
  return 1
}

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }

require_mac() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    red "This script requires macOS (Darwin). Current: $(uname -s)"
    exit 1
  fi
}

timestamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }
date_slug() { date -u +%Y%m%dT%H%M%SZ; }

dir_size_mb() {
  local path="$1"
  [[ -e "$path" ]] || { echo "0"; return; }
  du -sm "$path" 2>/dev/null | awk '{print $1}' || echo "0"
}

disk_free_gb() {
  df -g / 2>/dev/null | awk 'NR==2 {print $4}' || echo "?"
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

ensure_output_dirs() {
  mkdir -p "${ROOT}/output/audit" "${ROOT}/output/health"
}

log_health() {
  ensure_output_dirs
  local log="${ROOT}/output/health/$(date -u +%Y-%m-%d).log"
  echo "[$(timestamp)] $*" >> "$log"
  echo "$*"
}
