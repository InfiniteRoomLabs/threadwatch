#!/usr/bin/env bash
# smoke.sh — the one runnable check. Fails loudly if the wiring, sandbox, auth,
# or render logic is broken. Run after install.sh.
# Run standalone: ./smoke.sh         (offline checks + dry-run)
#                 ./smoke.sh --full  (also does ONE real timed run)
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "1/5 units parse + reference real paths"
systemd-analyze --user verify "$here/threadwatch.service"

echo "2/5 offline render/parse logic"
"$here/threadwatch" selfcheck

echo "3/5 config loads, prompt builds (dry-run, no claude/network)"
"$here/threadwatch" run --dry-run >/dev/null

echo "4/5 claude on PATH"
command -v claude >/dev/null || { echo "FAIL: claude not on PATH"; exit 127; }

if [ "${1:-}" = "--full" ]; then
    echo "5/5 real run via the unit (THIS spends subscription quota)"
    systemctl --user start threadwatch.service
    journalctl --user -u threadwatch -o cat -n10 | grep -q '"event": "run_complete"' \
        || { echo "FAIL: no run_complete in journal"; exit 1; }
    test -f "$HOME/threadwatch/THREADWATCH.md" || { echo "FAIL: report not written"; exit 1; }
    echo "report written: $HOME/threadwatch/THREADWATCH.md"
else
    echo "5/5 skipped real run (pass --full to spend quota and verify end-to-end)"
fi
echo "smoke OK"
