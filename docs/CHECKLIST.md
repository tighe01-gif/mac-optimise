# Mac optimization checklist

Human steps beyond automated scripts. Check off as completed.

## Disk and storage

- [ ] Run `scripts/audit.sh` — review `output/audit/latest.json`
- [ ] Free space ≥ 20 GB on system volume
- [ ] Empty Trash
- [ ] Review `~/Downloads` for large stale files
- [ ] iCloud: disable "Optimize Mac Storage" if causing sync stalls (System Settings → Apple ID → iCloud)

## Development caches

- [ ] `scripts/cleanup.sh --dry-run` then `scripts/cleanup.sh`
- [ ] Remove unused Docker images: `docker system prune` (if Docker installed)
- [ ] Review `node_modules` in old project folders

## Cursor and SSH

- [ ] `scripts/align-ecosystem.sh` — fix device-sync drift
- [ ] Close tabs with unsaved dots (●) after alignment
- [ ] Reopen Objoli via **Launch Objoli.app** (not local `~/objoli` folder)
- [ ] Verify Remote-SSH connects to `objoli-platform`

## Ecosystem health

- [ ] Objoli VM reachable: `ssh builder@<vm-ip> 'git -C /workspace/objoli rev-parse --short HEAD'`
- [ ] Pulse-Sync receiver running (if using phone sync)
- [ ] `scripts/install-maintain-launchd.sh` for daily autopilot

## Platform validation (optional)

See Objoli `platform/config/MAC_OPTIONAL_CHECKLIST.md` for Day 7 platform tests.
