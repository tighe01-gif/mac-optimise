#!/usr/bin/env bash
# Align Mac ecosystem repos and fix Cursor device-sync drift.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=mac-lib.sh
source "${ROOT}/scripts/mac-lib.sh"

require_mac

echo "=== Mac Optimise ecosystem alignment $(timestamp) ==="
echo ""

OBJOLI="${OBJOLI_MAC_PATH:-$HOME/objoli}"
FIX_SCRIPT="${OBJOLI}/infra/scripts/fix_device_sync_warning.sh"

if [[ -x "$FIX_SCRIPT" ]]; then
  green "Running Objoli device-sync fix…"
  OBJOLI_SKIP_SYNC=1 "$FIX_SCRIPT"
else
  yellow "Objoli fix script not found at ${FIX_SCRIPT}"
  yellow "Ensure ~/objoli is cloned and on worker/day5-a"
fi

echo ""
for name path in \
  "Pulse-Sync" "${PULSE_SYNC_PATH:-$HOME/Pulse-Sync}" \
  "mac-optimise" "$ROOT"; do
  if [[ -d "${path}/.git" ]]; then
    branch="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    if [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then
      yellow "${name}: dirty working tree on ${branch}"
    else
      green "${name}: clean on ${branch}"
    fi
  fi
done

echo ""
echo "Next: close Cursor tabs with unsaved dots (●), reopen via Launch Objoli.app"
echo "=== done ==="
