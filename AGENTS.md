# Agent instructions — Mac Optimise

## User preference

**Do everything automatable without asking.** Run audits, health checks, and safe cleanups proactively. Only stop for: destructive cleanup beyond the safe list, secrets, or physical Mac actions.

## One-command flows

| Goal | Command |
|------|---------|
| **Health snapshot** | `~/mac-optimise/scripts/health-check.sh` |
| Full audit (JSON report) | `~/mac-optimise/scripts/audit.sh` |
| Preview cleanup | `~/mac-optimise/scripts/cleanup.sh --dry-run` |
| Apply safe cleanup | `~/mac-optimise/scripts/cleanup.sh` |
| Fix Cursor device-sync drift | `~/mac-optimise/scripts/align-ecosystem.sh` |
| Daily maintenance (launchd) | `~/mac-optimise/scripts/install-maintain-launchd.sh` |

## Platform rules

- Scripts target **Darwin only** — guard with `uname -s` checks.
- Never delete user data, git repos, or `~/Library` outside documented cache paths.
- Objoli authority is `/workspace/objoli` on VM — Mac `~/objoli` is a read-only mirror.
- Generated reports go to `output/` — never commit `output/` except `.gitkeep`.

## Key paths

| Path | Purpose |
|------|---------|
| `scripts/mac-lib.sh` | Shared helpers (colors, JSON, disk checks) |
| `config/defaults.env` | Tunable thresholds |
| `output/audit/` | Timestamped audit JSON |
| `output/health/` | Health check logs |
| `docs/CHECKLIST.md` | Human optimization checklist |
