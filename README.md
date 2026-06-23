# threadwatch

An hourly, hardened, **read-only** `claude -p` job that scans private knowledge
archives for important/active email/knowledge threads and refreshes a
human-readable `~/threadwatch/THREADWATCH.md`, driven by a hand-edited
`.threadwatch.toml` watchlist.

Runs as a systemd `--user` timer on a personal Linux machine. Costs **$0/call**
— it rides your logged-in Claude subscription quota, not the API.

> Deployed to the laptop via [`infinite-room-labs-infra`](https://github.com/InfiniteRoomLabs/infinite-room-labs-infra)
> → `ansible/playbooks/laptop.yml`. This repo is the portable tool; that repo is the glue.

## Install

```bash
# Standalone (manual):
./install.sh            # symlink units + wrapper into ~/.config/systemd/user + ~/.local/bin, verify
./smoke.sh              # offline checks + dry-run
./install.sh --enable   # turn the hourly timer on
./smoke.sh --full       # one real run (spends a little subscription quota)

# Or via the infra ansible play (the managed path):
#   ./run-ansible.sh playbook playbooks/laptop.yml
```

Observe it:
```bash
systemctl --user list-timers threadwatch.timer
journalctl --user -u threadwatch -o cat -e
systemd-analyze security --user threadwatch.service   # sandbox exposure score
```

## The contract (two files, two directions)

| File | Direction | Who writes |
|------|-----------|-----------|
| `~/threadwatch/.threadwatch.toml` | **input** — settings + `[[watch]]` blocks (slug / why / match / urgency) | you, by hand |
| `~/threadwatch/THREADWATCH.md` | **output** — flagged + quiet threads, refreshed each run | the wrapper (never the model) |

Both live in `~/threadwatch/` (outside the scanned archives, outside this repo — PII).
`install.sh` seeds the config from `.threadwatch.toml.example` on first run.
`THREADWATCH.md` frontmatter follows the `layout_version: 1` contract so a downstream
indexer can parse it defensively.

## Layout

- `threadwatch` — the wrapper: single stdlib-only Python file (`uv run --script`, zero deps).
  Loads config, calls a **fully tool-locked** `claude -p` (Read/Grep/Glob only — no
  Write/Edit/Bash), validates the JSON, and is the **only** thing that writes the report.
  `threadwatch selfcheck` is an offline logic check.
- `threadwatch.{timer,service}` — user units. Hourly + jitter, no-linger ("only while
  logged in"), `Persistent=true` (catch up one missed run on login). The service is
  read-only everywhere except `~/threadwatch`, network kept open for the API. The inline
  comments name the directives that would **silently** break it.
- `.threadwatch.toml.example` — watchlist seed.
- `install.sh` / `smoke.sh` — idempotent installer + the one runnable check.

## Why it's shaped this way

- **Subscription `claude -p`, $0/call.** Mirrors `claude-ai-export`'s `claude_cli.py`. The
  only dependency is a logged-in `claude` session; if it expires the job exits
  `UNAVAILABLE` (69) and the journal status line shows it.
- **The model is read-only; the wrapper writes.** Chosen over "let the agent write the
  file" because an unattended model holding write tools *does the task and writes files*
  instead of returning data. Belt (systemd `ReadOnlyPaths`) + suspenders
  (`--disallowed-tools`) + the only writer is deterministic Python you can read.
- **sysexits exit codes + `flock` guard + JSON-to-journal logging** — so a healthcheck or
  the timer can decide retry-vs-alert from the exit code. Lifted from `claude-ai-export`.

## ⚠ Empirical unknown (verify at first real run)

`claude -p` on **subscription** auth inside a bare `--user` unit (no TTY, sandboxed) is
proven from a shell but unproven headless here. The auth state (`~/.claude`,
`~/.claude.json`) is kept readable; confirm with `./smoke.sh --full` before trusting the
hourly timer. There's a `systemd-run --user` sandbox probe in the unit comments to catch
DNS/network/FS breakage without installing the unit.

## Sandbox directives deliberately left out (would break it)

- `PrivateNetwork=yes` — kills the API.
- `IPAddressDeny=any` — cgroup-eBPF is unreliable under `--user`; would silently break the
  systemd-resolved loopback DNS stub. Do egress pinning at nftables, not here.
- `ProtectHome=tmpfs` — would make the input archives vanish → silent empty report.
- `MemoryDenyWriteExecute=true` — breaks JIT if a node/V8 `claude` path is ever reintroduced.

## Roadmap (parked)

| Item | Tag | Note |
|------|-----|------|
| claudesync re-sync + `reindex` before the scan | keep | wrapper pre-step once v1 proves out |
| indexer auto-writes the watchlist | reconsider | inverts the human-writes-config contract |
| claude.ai SKILL package + Claude-Web context injection | keep | already solved by the disability-orchestration skill/plugin — reskin |
| CLI tooling over indexer metadata (deterministic metrics) | keep | cheap, no quota; v2 |
| homelab Postgres+pgvector + ollama query path | reconsider | whole retrieval subsystem; YAGNI for v1 |
| Windows GTX1070 ollama node | drop | speculative always-on dependency |
| Teams / Calendar-description as a thread source | reconsider | live network source; breaks "local archives" scope |
| gmail-ai-broker + Gmail MCP | keep | email is the disability wedge; blocked on broker OAuth |
| Claude Code Web v2 | drop | v1 is a local job |
| opencode / other harnesses | drop | 413-blocked on Groq free tier |

Generalized from the `disability-orchestration` artifacts in `claude-ai-export`
(`LAYOUT.md` frontmatter contract, `CHANGELOG.md` scope-slug event stream, and the
multi-surface skill/plugin).
