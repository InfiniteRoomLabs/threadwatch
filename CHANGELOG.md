# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.5] - 2026-06-26

### Fixed
- `threadwatch.service`: added an `ExecStartPre` boot-readiness gate. After a power-loss reboot the `Persistent=true` catch-up run fires before the network/`claude` session is ready and exits `69/UNAVAILABLE` (observed: started 18:38:40, `claude_failed` 22s later). The gate blocks up to 120s for Anthropic reachability, then proceeds (a real outage is logged and retried next 5h window). Verified `curl` runs inside the unit's strict sandbox.

## [0.1.4] - 2026-06-25

### Changed
- `threadwatch`: added a `# vim: ft=python` modeline so editors syntax-highlight the
  `uv run --script` wrapper as Python.

## [0.1.3] - 2026-06-24

### Changed
- `threadwatch.timer`: cadence from hourly to every 5 hours at `:15`
  (`OnCalendar=*-*-* 00/5:15:00`). One scan per Claude 5-hour usage window, and it
  lands after the hourly claudesync export (which runs at `:00`) so the archive is
  fresh. Pairs with the new `claudesync.timer` in the claude-ai-export repo.

## [0.1.2] - 2026-06-23

### Security
- `threadwatch.service`: `UnsetEnvironment=ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN`.
  `claude -p` prefers an API key over the OAuth session, so an inherited key would
  silently turn the timer into paid API calls. Stripping it guarantees subscription
  ($0) auth regardless of the surrounding environment.

## [0.1.1] - 2026-06-23

### Fixed
- `threadwatch.service`: dropped `CapabilityBoundingSet`/`AmbientCapabilities` and the
  `ProtectKernelModules`/`ProtectKernelLogs`/`ProtectClock` directives. In a `--user`
  manager they try to drop bounding-set capabilities without `CAP_SETPCAP` and fail the
  unit with `218/CAPABILITIES`. The process is unprivileged, so nothing is lost.
- `threadwatch.service`: removed `@resources` from the syscall deny-list. `claude` uses
  sched/rlimit syscalls in that group and was being SIGSYS-killed (`69/UNAVAILABLE`).
- `threadwatch.timer`: moved inline comments off the `Persistent=`/`RandomizedDelaySec=`
  lines (systemd has no inline comments, so the values were silently ignored).
- `install.sh`: replaced the `usage` shebang with plain bash arg parsing; the installed
  `usage` version parsed the script as KDL and failed under ansible/systemd.

### Verified
- End-to-end run inside the hardened `--user` unit on subscription `claude -p`: clean
  `run_complete`, report written, sandbox holds. The headless-auth unknown is resolved.

## [0.1.0] - 2026-06-23

### Added
- Initial release. `threadwatch` wrapper: a single stdlib-only Python file
  (`uv run --script`) that runs a fully tool-locked, read-only `claude -p` over
  configured archives and renders `THREADWATCH.md`. The wrapper is the only writer.
- Hardened systemd `--user` units (`threadwatch.timer` + `threadwatch.service`):
  hourly with jitter, no-linger, `Persistent=true`, read-only filesystem except
  `~/threadwatch`, network kept open for the API.
- `flock` single-instance guard, sysexits exit codes, JSON-to-journal logging,
  and a `selfcheck` subcommand for offline render/parse verification.
- `install.sh` (idempotent installer) and `smoke.sh` (the one runnable check).
- `.threadwatch.toml.example` watchlist seed and the `layout_version: 1` report contract.
