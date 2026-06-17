#!/usr/bin/env bash
# One command: full read-only Mac health (disk, caches, ecosystem, thin client).
#
# Usage:
#   ./scripts/status.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=mac-lib.sh
source "${ROOT}/scripts/mac-lib.sh"

require_mac

exit_rc=0

"${ROOT}/scripts/health-check.sh" || exit_rc=$?

echo ""
echo "────────────────────────────────────────"
echo ""

"${ROOT}/scripts/thin-client-optimize.sh" --check || exit_rc=$?

exit "$exit_rc"
