# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
