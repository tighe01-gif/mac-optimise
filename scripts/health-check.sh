#!/usr/bin/env bash
# Read-only Mac health snapshot.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=mac-lib.sh
source "${ROOT}/scripts/mac-lib.sh"

require_mac
ensure_output_dirs

echo "=== Mac Optimise health check $(timestamp) ==="
echo ""

FREE_GB="$(disk_free_gb)"
echo "Disk free (root): ${FREE_GB} GB"
if [[ "$FREE_GB" != "?" ]] && [[ "$FREE_GB" -lt "${DISK_CRITICAL_GB:-10}" ]]; then
  red "CRITICAL: disk below ${DISK_CRITICAL_GB} GB free"
elif [[ "$FREE_GB" != "?" ]] && [[ "$FREE_GB" -lt "${DISK_WARN_GB:-20}" ]]; then
  yellow "WARN: disk below ${DISK_WARN_GB} GB free"
else
  green "Disk OK"
fi

echo ""
echo "Cache sizes:"
while IFS='|' read -r label path; do
  mb="$(dir_size_mb "$path")"
  echo "  ${label}: ${mb} MB"
done <<EOF
Cursor|${HOME}/Library/Application Support/Cursor
npm|${HOME}/.npm
Homebrew|$(brew --cache 2>/dev/null || echo /dev/null)
Xcode DerivedData|${HOME}/Library/Developer/Xcode/DerivedData
EOF

echo ""
echo "Ecosystem repos:"
while IFS='|' read -r name path; do
  if [[ -d "${path}/.git" ]]; then
    branch="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")"
    short="$(git -C "$path" rev-parse --short HEAD 2>/dev/null || echo "?")"
    echo "  ${name}: ${branch} @ ${short}"
  elif [[ -d "$path" ]]; then
    yellow "  ${name}: present (no .git)"
  else
    echo "  ${name}: not found"
  fi
done <<EOF
objoli|${OBJOLI_MAC_PATH:-$HOME/objoli}
Pulse-Sync|${PULSE_SYNC_PATH:-$HOME/Pulse-Sync}
Pulse Loop|${PULSE_LOOP_PATH:-$HOME/Pulse Loop}
EOF

echo ""
echo "Launchd maintenance:"
if launchctl list 2>/dev/null | grep -q "${LAUNCHD_LABEL:-com.mac.optimise.maintain}"; then
  green "  ${LAUNCHD_LABEL:-com.mac.optimise.maintain}: loaded"
else
  echo "  ${LAUNCHD_LABEL:-com.mac.optimise.maintain}: not loaded"
fi

log_health "health-check complete — disk ${FREE_GB} GB free"
echo ""
echo "=== done ==="
