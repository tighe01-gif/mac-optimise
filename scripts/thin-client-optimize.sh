#!/usr/bin/env bash
# Optimise MacBook as Objoli thin client: cleanup + posture verification.
#
# Thin client = Mac is cockpit only (SSH, Cursor Remote-SSH, Pulse local).
# Platform authority lives on VM /workspace/objoli — not on Mac disk.
#
# Usage:
#   ./scripts/thin-client-optimize.sh           # verify + cleanup + align
#   ./scripts/thin-client-optimize.sh --check   # verify only (no changes)
#   ./scripts/thin-client-optimize.sh --dry-run # verify + preview cleanup
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=mac-lib.sh
source "${ROOT}/scripts/mac-lib.sh"

require_mac

MODE=run
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE=check; shift ;;
    --dry-run) MODE=dry-run; shift ;;
    --help|-h)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) red "Unknown option: $1"; exit 1 ;;
  esac
done

OBJOLI_MAC="${OBJOLI_MAC_PATH:-$HOME/objoli}"
SSH_HOST="${OBJOLI_SSH_HOST:-objoli-platform}"
VM_AUTHORITY="${OBJOLI_VM_AUTHORITY:-/workspace/objoli}"
OBJOLI_BRANCH="${OBJOLI_GITHUB_BRANCH:-worker/day5-a}"
REPORT_DIR="${ROOT}/output/thin-client"
REPORT="${REPORT_DIR}/$(date_slug).json"
LATEST="${REPORT_DIR}/latest.json"

mkdir -p "$REPORT_DIR"

PASS=0
WARN=0
FAIL=0

pass() { green "PASS: $*"; PASS=$((PASS + 1)); }
warn() { yellow "WARN: $*"; WARN=$((WARN + 1)); }
fail() { red "FAIL: $*"; FAIL=$((FAIL + 1)); }

echo "=== Mac thin client optimise $(timestamp) ==="
echo "Mode: ${MODE}"
echo ""

# --- 1. Disk (thin client needs headroom for Cursor + Pulse caches) ---
FREE_GB="$(disk_free_gb)"
echo "--- Disk ---"
if [[ "$FREE_GB" != "?" ]] && [[ "$FREE_GB" -lt "${DISK_CRITICAL_GB:-10}" ]]; then
  fail "disk ${FREE_GB} GB free (critical < ${DISK_CRITICAL_GB} GB)"
elif [[ "$FREE_GB" != "?" ]] && [[ "$FREE_GB" -lt "${DISK_WARN_GB:-20}" ]]; then
  warn "disk ${FREE_GB} GB free (low < ${DISK_WARN_GB} GB)"
else
  pass "disk ${FREE_GB} GB free"
fi
echo ""

# --- 2. SSH thin client path ---
echo "--- SSH → platform ---"
if [[ -f "${HOME}/.ssh/config" ]] && grep -qE "^[[:space:]]*Host[[:space:]]+${SSH_HOST}([[:space:]]|$)" "${HOME}/.ssh/config" 2>/dev/null; then
  pass "SSH config has Host ${SSH_HOST}"
else
  fail "missing Host ${SSH_HOST} in ~/.ssh/config"
fi

if ssh -o ConnectTimeout=8 -o BatchMode=yes "${SSH_HOST}" "test -d '${VM_AUTHORITY}/.git'" 2>/dev/null; then
  pass "VM reachable — ${SSH_HOST}:${VM_AUTHORITY} exists"
else
  fail "cannot SSH to ${SSH_HOST} or ${VM_AUTHORITY} missing"
fi

if ssh -o ConnectTimeout=8 -o BatchMode=yes "${SSH_HOST}" \
  "git -C '${VM_AUTHORITY}' rev-parse --abbrev-ref HEAD" &>/dev/null; then
  vm_branch="$(ssh -o ConnectTimeout=8 -o BatchMode=yes "${SSH_HOST}" \
    "git -C '${VM_AUTHORITY}' rev-parse --abbrev-ref HEAD" 2>/dev/null || echo "?")"
  vm_short="$(ssh -o ConnectTimeout=8 -o BatchMode=yes "${SSH_HOST}" \
    "git -C '${VM_AUTHORITY}' rev-parse --short HEAD" 2>/dev/null || echo "?")"
  if [[ "$vm_branch" == "$OBJOLI_BRANCH" ]]; then
    pass "VM objoli on ${OBJOLI_BRANCH} @ ${vm_short}"
  else
    warn "VM objoli on ${vm_branch} (expected ${OBJOLI_BRANCH})"
  fi
else
  fail "VM objoli git check failed"
fi

if ssh -o ConnectTimeout=8 -o BatchMode=yes "${SSH_HOST}" \
  "test -x '${VM_AUTHORITY}/infra/scripts/validate_objoli_source.sh'" 2>/dev/null; then
  if ssh -o ConnectTimeout=8 -o BatchMode=yes "${SSH_HOST}" \
    "'${VM_AUTHORITY}/infra/scripts/validate_objoli_source.sh'" &>/dev/null; then
    pass "VM validate_objoli_source.sh"
  else
    warn "VM validate_objoli_source.sh reported issues"
  fi
fi
echo ""

# --- 3. Mac mirror (client only — must not be edit authority) ---
echo "--- Mac client mirror ---"
if [[ -d "${OBJOLI_MAC}/.git" ]]; then
  mac_branch="$(git -C "${OBJOLI_MAC}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")"
  mac_short="$(git -C "${OBJOLI_MAC}" rev-parse --short HEAD 2>/dev/null || echo "?")"
  if [[ "$mac_branch" == "$OBJOLI_BRANCH" ]]; then
    pass "Mac ~/objoli on ${OBJOLI_BRANCH} @ ${mac_short}"
  else
    warn "Mac ~/objoli on ${mac_branch} (expected ${OBJOLI_BRANCH})"
  fi
  if [[ -n "$(git -C "${OBJOLI_MAC}" status --porcelain 2>/dev/null)" ]]; then
    warn "Mac ~/objoli has local edits — use Remote-SSH to ${VM_AUTHORITY}, not Mac clone"
  else
    pass "Mac ~/objoli clean (client mirror)"
  fi
  if [[ -n "${vm_short:-}" && "$vm_short" != "?" && "$mac_short" != "$vm_short" ]]; then
    warn "Mac HEAD ${mac_short} != VM HEAD ${vm_short} — run: cd ~/objoli && git pull --ff-only"
  elif [[ "$mac_short" == "${vm_short:-}" ]]; then
    pass "Mac ~/objoli HEAD matches VM"
  fi
else
  warn "Mac ~/objoli not cloned (optional mirror; Remote-SSH is enough)"
fi

for app in "Launch Objoli.app" "Launch Platform.app"; do
  if [[ -d "${HOME}/Desktop/${app}" ]]; then
    pass "Desktop/${app} installed"
  else
    warn "Desktop/${app} missing — run ~/objoli/infra/scripts/install_desktop_launcher.sh"
  fi
done
echo ""

# --- 4. Local product clients (allowed on thin client) ---
echo "--- Local clients (Pulse) ---"
while IFS='|' read -r label dir; do
  [[ -d "${dir}/.git" ]] && pass "${label} present" || warn "${label} not found at ${dir}"
done <<EOF
Pulse Loop|${PULSE_LOOP_PATH:-$HOME/Pulse Loop}
Pulse-Sync|${PULSE_SYNC_PATH:-$HOME/Pulse-Sync}
EOF

if launchctl list 2>/dev/null | grep -q "${LAUNCHD_LABEL:-com.mac.optimise.maintain}"; then
  pass "mac-optimise daily maintenance loaded"
else
  warn "mac-optimise launchd not loaded — run ./scripts/install-maintain-launchd.sh"
fi
echo ""

# --- 5. Optimise (cleanup + align) ---
if [[ "$MODE" == "check" ]]; then
  yellow "Check-only — skipping cleanup and align"
else
  echo "--- Optimise ---"
  if [[ "$MODE" == "dry-run" ]]; then
    "${ROOT}/scripts/cleanup.sh" --dry-run || true
  else
    "${ROOT}/scripts/cleanup.sh" || true
    if [[ -x "${OBJOLI_MAC}/infra/scripts/fix_device_sync_warning.sh" ]]; then
      OBJOLI_SKIP_SYNC=1 "${OBJOLI_MAC}/infra/scripts/fix_device_sync_warning.sh" || warn "device-sync fix had issues"
    else
      "${ROOT}/scripts/align-ecosystem.sh" || true
    fi
  fi
  echo ""
fi

# --- Report ---
python3 <<PY
import json, datetime, os
report = {
    "timestamp": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    "mode": "${MODE}",
    "disk_free_gb": "${FREE_GB}",
    "ssh_host": "${SSH_HOST}",
    "vm_authority": "${VM_AUTHORITY}",
    "pass": ${PASS},
    "warn": ${WARN},
    "fail": ${FAIL},
    "thin_client_ok": ${FAIL} == 0,
}
os.makedirs("${REPORT_DIR}", exist_ok=True)
with open("${REPORT}", "w") as f:
    json.dump(report, f, indent=2)
import shutil
shutil.copy("${REPORT}", "${LATEST}")
print(f"Report: ${REPORT}")
PY

echo ""
echo "--- Summary: ${PASS} pass, ${WARN} warn, ${FAIL} fail ---"
if [[ "$FAIL" -gt 0 ]]; then
  red "Thin client posture: NEEDS ATTENTION"
  echo "Fix: open Cursor via Launch Objoli.app → ${SSH_HOST}:${VM_AUTHORITY}"
  exit 1
fi
if [[ "$WARN" -gt 0 ]]; then
  yellow "Thin client posture: OK with warnings"
else
  green "Thin client posture: OK"
fi
echo "=== done ==="
