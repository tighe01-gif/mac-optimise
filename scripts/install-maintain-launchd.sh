#!/usr/bin/env bash
# Install daily Mac Optimise maintenance via launchd (6:30 AM).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=mac-lib.sh
source "${ROOT}/scripts/mac-lib.sh"

require_mac

LABEL="${LAUNCHD_LABEL:-com.mac.optimise.maintain}"
PLIST_SRC="${ROOT}/scripts/com.mac.optimise.maintain.plist.template"
PLIST_DST="${HOME}/Library/LaunchAgents/${LABEL}.plist"

mkdir -p "${HOME}/Library/LaunchAgents"
sed "s|__MAC_OPTIMISE_ROOT__|${ROOT}|g" "$PLIST_SRC" > "$PLIST_DST"

launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"
launchctl enable "gui/$(id -u)/${LABEL}"
launchctl kickstart -k "gui/$(id -u)/${LABEL}" 2>/dev/null || true

green "Installed ${LABEL}"
echo "  Plist: ${PLIST_DST}"
echo "  Log:   /tmp/mac-optimise-maintain.log"
echo "  Test:  ${ROOT}/scripts/maintain-autopilot.sh"
