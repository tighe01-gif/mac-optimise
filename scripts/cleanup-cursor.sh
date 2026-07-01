#!/usr/bin/env bash
# Auto-clear Cursor caches and prune bloated chat/agent state (state.vscdb).
#
# Safe caches are cleared even while Cursor is running.
# Blob prune + VACUUM run only when Cursor is quit (config: CURSOR_PRUNE_WHEN_RUNNING=0).
#
# Usage:
#   ./scripts/cleanup-cursor.sh
#   ./scripts/cleanup-cursor.sh --dry-run
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=mac-lib.sh
source "${ROOT}/scripts/mac-lib.sh"

require_mac

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

CURSOR_ROOT="${CURSOR_APP_SUPPORT:-${HOME}/Library/Application Support/Cursor}"
STATE_DB="${CURSOR_ROOT}/User/globalStorage/state.vscdb"

# Subdirs under Cursor app support — contents cleared, dirs kept.
CURSOR_CACHE_DIRS=(
  "logs"
  "snapshots"
  "GPUCache"
  "Code Cache"
  "CachedData"
  "Cache"
  "CachedProfilesData"
  "DawnWebGPUCache"
  "DawnGraphiteCache"
  "Crashpad/completed"
  "sentry"
  "Service Worker/CacheStorage"
)

cursor_is_running() {
  pgrep -f "/Applications/Cursor.app/Contents/MacOS/Cursor" >/dev/null 2>&1
}

sqlite_bin() {
  if [[ -x /usr/bin/sqlite3 ]]; then
    echo /usr/bin/sqlite3
  elif command -v sqlite3 &>/dev/null; then
    command -v sqlite3
  else
    return 1
  fi
}

clear_dir_contents() {
  local rel="$1"
  local dir="${CURSOR_ROOT}/${rel}"
  [[ -d "$dir" ]] || return 0
  local mb
  mb="$(dir_size_mb "$dir")"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    yellow "[dry-run] would clear Cursor ${rel} (${mb} MB)"
    return 0
  fi
  find "$dir" -mindepth 1 -delete 2>/dev/null || rm -rf "${dir:?}"/* 2>/dev/null || true
  green "Cleared Cursor ${rel} (${mb} MB)"
}

prune_state_blobs() {
  [[ "${CURSOR_AUTO_PRUNE_BLOBS:-1}" == "1" ]] || return 0
  [[ -f "$STATE_DB" ]] || return 0

  local sql max_mb batch prune_when_running freed_before freed_after
  max_mb="${CURSOR_STATE_MAX_MB:-1500}"
  batch="${CURSOR_PRUNE_BATCH:-50000}"
  prune_when_running="${CURSOR_PRUNE_WHEN_RUNNING:-0}"

  if cursor_is_running && [[ "$prune_when_running" != "1" ]]; then
    yellow "Cursor running — skipping state.vscdb prune (quit Cursor or set CURSOR_PRUNE_WHEN_RUNNING=1)"
    return 0
  fi

  local db_mb
  db_mb="$(dir_size_mb "$STATE_DB")"
  if [[ "$db_mb" -le "$max_mb" ]]; then
    [[ "$DRY_RUN" -eq 1 ]] && yellow "[dry-run] state.vscdb ${db_mb} MB ≤ ${max_mb} MB — no prune needed"
    return 0
  fi

  local sqlite
  sqlite="$(sqlite_bin)" || {
    yellow "sqlite3 not found — skipping state.vscdb prune"
    return 0
  }

  if [[ "$DRY_RUN" -eq 1 ]]; then
    yellow "[dry-run] would prune state.vscdb from ${db_mb} MB toward ≤ ${max_mb} MB"
    return 0
  fi

  freed_before="$db_mb"
  while [[ "$db_mb" -gt "$max_mb" ]]; do
    local deleted
    deleted="$("$sqlite" "$STATE_DB" "DELETE FROM cursorDiskKV WHERE rowid IN (SELECT rowid FROM cursorDiskKV WHERE key LIKE 'bubbleId:%' OR key LIKE 'agentKv:blob:%' ORDER BY rowid ASC LIMIT ${batch}); SELECT changes();")"
    [[ "${deleted:-0}" -gt 0 ]] || break
    db_mb="$(dir_size_mb "$STATE_DB")"
  done

  "$sqlite" "$STATE_DB" "PRAGMA wal_checkpoint(TRUNCATE); VACUUM;" 2>/dev/null || true
  freed_after="$(dir_size_mb "$STATE_DB")"
  green "Pruned state.vscdb: ${freed_before} MB → ${freed_after} MB (target ≤ ${max_mb} MB)"
}

echo "=== Cursor auto-clear $(timestamp) ==="
[[ "$DRY_RUN" -eq 1 ]] && yellow "DRY RUN — no changes"
echo ""

for rel in "${CURSOR_CACHE_DIRS[@]}"; do
  clear_dir_contents "$rel"
done

prune_state_blobs

echo ""
echo "=== done ==="
log_health "cursor auto-clear complete (dry_run=${DRY_RUN})"
