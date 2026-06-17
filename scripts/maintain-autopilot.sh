#!/usr/bin/env bash
# Daily maintenance — health check + safe cleanup (launchd target).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=mac-lib.sh
source "${ROOT}/scripts/mac-lib.sh"

LOG="/tmp/mac-optimise-maintain.log"
exec >>"$LOG" 2>&1

echo "=== maintain $(timestamp) ==="

"$ROOT/scripts/health-check.sh" || true
"$ROOT/scripts/cleanup.sh" || true

echo "=== done ==="
