#!/usr/bin/env bash
# Remove Mac Optimise launchd maintenance job.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=mac-lib.sh
source "${ROOT}/scripts/mac-lib.sh"

require_mac

LABEL="${LAUNCHD_LABEL:-com.mac.optimise.maintain}"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"

launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
rm -f "$PLIST"

green "Removed ${LABEL}"
