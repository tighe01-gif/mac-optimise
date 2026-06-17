# Architecture

Mac Optimise is a **Mac-only** shell toolkit. It does not run on the Objoli VM except for editing via Cursor Remote-SSH.

## Design

```
┌─────────────────────────────────────────────────────────┐
│  macOS (development Mac)                                │
│                                                         │
│  ~/mac-optimise/scripts/                                │
│    health-check.sh  ──► output/health/                  │
│    audit.sh         ──► output/audit/latest.json        │
│    cleanup.sh       ──► caches, brew, DerivedData       │
│    align-ecosystem.sh ──► ~/objoli/infra/scripts/...  │
│    maintain-autopilot.sh ◄── launchd (6:30 AM)          │
└─────────────────────────────────────────────────────────┘
         │
         │ Remote-SSH (edit only)
         ▼
┌─────────────────────────────────────────────────────────┐
│  VM (objoli-platform)                                   │
│  /workspace/mac-optimise  — git authority (optional)    │
│  /workspace/objoli        — platform authority            │
└─────────────────────────────────────────────────────────┘
```

## Boundaries

| Concern | Owner |
|---------|-------|
| Mac disk/cache cleanup | **mac-optimise** |
| Objoli git authority / device-sync | **objoli** `fix_device_sync_warning.sh` |
| Phone → Mac sync health | **Pulse-Sync** `maintain-autopilot.sh` |
| Platform VM ops | **objoli** infra scripts |

## Safety model

Cleanup targets are **regenerable caches only**:

- Homebrew download cache
- npm / pip caches
- Xcode DerivedData
- Cursor GPU/Code caches
- User-owned `/tmp` files older than 7 days

Never touched: git repos, `~/Documents`, media libraries, application data.

## Output artifacts

| Type | Location | Retention |
|------|----------|-----------|
| Audit JSON | `output/audit/YYYYMMDDTHHMMSSZ.json` | Local; gitignored |
| Latest audit | `output/audit/latest.json` | Overwritten each run |
| Health log | `output/health/YYYY-MM-DD.log` | Appended daily |
| Maintain log | `/tmp/mac-optimise-maintain.log` | launchd stdout |
