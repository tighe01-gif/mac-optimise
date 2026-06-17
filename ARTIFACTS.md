# Artifact inventory — Mac Optimise

**Updated:** 2026-06-17  
**Status:** All artifacts created (greenfield bootstrap).

## Documentation

| Artifact | Path | Status |
|----------|------|--------|
| Project README | `README.md` | Created |
| Agent instructions | `AGENTS.md` | Created |
| This inventory | `ARTIFACTS.md` | Created |
| Optimization checklist | `docs/CHECKLIST.md` | Created |
| Architecture notes | `docs/ARCHITECTURE.md` | Created |

## Configuration

| Artifact | Path | Status |
|----------|------|--------|
| Default thresholds | `config/defaults.env` | Created |
| DJ protected paths | `config/dj-protected-paths.env` | Created |
| Cursor rule | `.cursor/rules/mac-optimise.mdc` | Created |
| Git ignore | `.gitignore` | Created |

## Scripts

| Artifact | Path | Status |
|----------|------|--------|
| Shared library | `scripts/mac-lib.sh` | Created |
| **Thin client optimise** | `scripts/thin-client-optimize.sh` | Created |
| Health check | `scripts/health-check.sh` | Created |
| Full status (one command) | `scripts/status.sh` | Created |
| Full audit | `scripts/audit.sh` | Created |
| Safe cleanup | `scripts/cleanup.sh` | Created |
| Ecosystem alignment | `scripts/align-ecosystem.sh` | Created |
| Install launchd | `scripts/install-maintain-launchd.sh` | Created |
| Disable launchd | `scripts/disable-maintain-launchd.sh` | Created |
| Launchd template | `scripts/com.mac.optimise.maintain.plist.template` | Created |

## Generated output (runtime)

| Artifact | Path | Status |
|----------|------|--------|
| Audit reports | `output/audit/*.json` | Created on first `audit.sh` run |
| Health logs | `output/health/*.log` | Created on first `health-check.sh` run |
| Thin client reports | `output/thin-client/latest.json` | Created by `thin-client-optimize.sh` |
| Maintain log | `/tmp/mac-optimise-maintain.log` | Created when launchd runs |

## External references (not in this repo)

| Artifact | Location | Notes |
|----------|----------|-------|
| Objoli device-sync fix | `~/objoli/infra/scripts/fix_device_sync_warning.sh` | Called by `align-ecosystem.sh` |
| Mac optional checklist | `objoli/platform/config/MAC_OPTIONAL_CHECKLIST.md` | Platform validation |
| Pulse autopilot | `~/Pulse-Sync/scripts/maintain-autopilot.sh` | Separate concern — phone sync |

## Search results (2026-06-17)

- GitHub repo: https://github.com/tighe01-gif/mac-optimise (`main`)
- No existing files in `/workspace/mac-optimise` before bootstrap.
- Registered in `objoli/platform/config/projects.json` (rsync → `/products/mac-optimise`).
- Mac rsync manifest: `objoli/infra/cursor-projects.txt` → `~/mac-optimise`.
