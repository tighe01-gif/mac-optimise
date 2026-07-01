#!/usr/bin/env bash
# Safe Mac cleanup — caches and temp files only.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=mac-lib.sh
source "${ROOT}/scripts/mac-lib.sh"

require_mac

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    yellow "[dry-run] $*"
  else
    echo "+ $*"
    eval "$@"
  fi
}

echo "=== Mac Optimise cleanup $(timestamp) ==="
[[ "$DRY_RUN" -eq 1 ]] && yellow "DRY RUN — no changes"
echo ""

# Homebrew
if command -v brew &>/dev/null; then
  run_cmd "brew cleanup -s 2>/dev/null || true"
  run_cmd "brew autoremove 2>/dev/null || true"
fi

# npm cache
if command -v npm &>/dev/null; then
  run_cmd "npm cache clean --force 2>/dev/null || true"
fi

# pip cache
if command -v pip3 &>/dev/null; then
  run_cmd "pip3 cache purge 2>/dev/null || true"
fi

# Xcode DerivedData (safe — rebuilds on next compile)
DERIVED="${HOME}/Library/Developer/Xcode/DerivedData"
if [[ -d "$DERIVED" ]]; then
  before="$(dir_size_mb "$DERIVED")"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    yellow "[dry-run] would remove Xcode DerivedData (${before} MB)"
  else
    rm -rf "${DERIVED:?}"/*
    after="$(dir_size_mb "$DERIVED")"
    green "Xcode DerivedData: ${before} MB → ${after} MB"
  fi
fi

# Old /tmp files
MAX_AGE="${TMP_MAX_AGE_DAYS:-7}"
if [[ "$DRY_RUN" -eq 1 ]]; then
  yellow "[dry-run] would delete /tmp files older than ${MAX_AGE} days (user-owned)"
else
  find /tmp -maxdepth 1 -user "$(whoami)" -mtime +"${MAX_AGE}" -type f -delete 2>/dev/null || true
  green "Pruned /tmp files older than ${MAX_AGE} days"
fi

# Cursor — logs, browser caches, and optional state.vscdb blob prune
if [[ "${CURSOR_AUTO_CLEAR:-1}" == "1" ]]; then
  cursor_args=()
  [[ "$DRY_RUN" -eq 1 ]] && cursor_args+=(--dry-run)
  "${ROOT}/scripts/cleanup-cursor.sh" "${cursor_args[@]}"
fi

echo ""
echo "=== done ==="
log_health "cleanup complete (dry_run=${DRY_RUN})"
