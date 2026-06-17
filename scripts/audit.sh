#!/usr/bin/env bash
# Full Mac audit — writes JSON to output/audit/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=mac-lib.sh
source "${ROOT}/scripts/mac-lib.sh"

require_mac
ensure_output_dirs

OUT="${ROOT}/output/audit/$(date_slug).json"
LATEST="${ROOT}/output/audit/latest.json"

python3 <<PY
import json, os, subprocess, shutil, datetime

root = os.environ.get("ROOT_OVERRIDE", "${ROOT}")
home = os.path.expanduser("~")

def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def dir_mb(path):
    if not os.path.exists(path):
        return 0
    try:
        out = subprocess.check_output(["du", "-sm", path], text=True, stderr=subprocess.DEVNULL)
        return int(out.split()[0])
    except Exception:
        return 0

def disk_free_gb():
    try:
        out = subprocess.check_output(["df", "-g", "/"], text=True)
        return int(out.splitlines()[1].split()[3])
    except Exception:
        return None

def git_info(path):
    if not os.path.isdir(os.path.join(path, ".git")):
        return None
    return {
        "branch": run(f"git -C {path!r} rev-parse --abbrev-ref HEAD"),
        "head": run(f"git -C {path!r} rev-parse --short HEAD"),
        "dirty": bool(run(f"git -C {path!r} status --porcelain")),
    }

brew_cache = run("brew --cache") or "/dev/null"
paths = {
    "cursor": os.path.join(home, "Library/Application Support/Cursor"),
    "npm": os.path.join(home, ".npm"),
    "brew_cache": brew_cache,
    "xcode_derived": os.path.join(home, "Library/Developer/Xcode/DerivedData"),
    "cargo": os.path.join(home, ".cargo/registry"),
    "gradle": os.path.join(home, ".gradle/caches"),
}

report = {
    "timestamp": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    "hostname": run("hostname -s") or run("hostname"),
    "os": run("sw_vers -productVersion"),
    "arch": run("uname -m"),
    "disk_free_gb": disk_free_gb(),
    "home_mb": dir_mb(home),
    "caches_mb": {k: dir_mb(v) for k, v in paths.items()},
    "repos": {
        "objoli": git_info(os.path.join(home, "objoli")),
        "pulse_sync": git_info(os.path.join(home, "Pulse-Sync")),
        "pulse_loop": git_info(os.path.join(home, "Pulse Loop")),
        "mac_optimise": git_info(root),
    },
    "launchd": {
        "maintain_loaded": "com.mac.optimise.maintain" in run("launchctl list"),
    },
}

os.makedirs(os.path.dirname("${OUT}"), exist_ok=True)
with open("${OUT}", "w") as f:
    json.dump(report, f, indent=2)
shutil.copy("${OUT}", "${LATEST}")
print(json.dumps(report, indent=2))
print(f"\nWrote ${OUT}")
print(f"Latest: ${LATEST}")
PY
