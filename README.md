# Mac Optimise

Mac development machine health, cleanup, and alignment for the Objoli / Pulse ecosystem.

Runs on **macOS only**. Clone to `~/mac-optimise` on your Mac (or open via Cursor Remote-SSH at `/workspace/mac-optimise` on the VM for editing).

## Mac setup

```bash
git clone git@github.com:tighe01-gif/mac-optimise.git ~/mac-optimise
cd ~/mac-optimise
./scripts/health-check.sh
```

VM authority: `/workspace/mac-optimise` (same repo). Mac mirror rsyncs to `/products/mac-optimise` via `objoli/infra/scripts/sync_all_cursor_projects_to_vm.sh`.

## Quick start

```bash
cd ~/mac-optimise
./scripts/thin-client-optimize.sh        # full: verify thin client + cleanup + align
./scripts/thin-client-optimize.sh --check   # verify only, no changes
./scripts/health-check.sh          # read-only status
./scripts/audit.sh                 # full audit → output/audit/latest.json
./scripts/cleanup.sh --dry-run     # preview safe cleanups
./scripts/cleanup.sh               # apply safe cleanups
./scripts/align-ecosystem.sh       # fix Cursor device-sync drift
./scripts/relocate-chang-audio.sh  # find Chang audio → iCloud Main DL (dry-run)
```

## Scheduled maintenance

```bash
./scripts/install-maintain-launchd.sh    # daily health + light cleanup
./scripts/disable-maintain-launchd.sh    # remove schedule
```

## Artifacts

See [ARTIFACTS.md](./ARTIFACTS.md) for the full inventory of scripts, configs, docs, and generated output.

## Related projects

| Project | Role |
|---------|------|
| `~/objoli` | Platform authority — Remote-SSH to `/workspace/objoli` |
| `~/Pulse-Sync` | Phone → Mac sync autopilot |
| `~/Pulse Loop` | Pulse Mac desktop app |
