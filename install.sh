#!/usr/bin/env -S usage bash
# USAGE flag "-e --enable" "Also enable + start the timer (default: install + verify only)"
# USAGE flag "-n --dry-run" "Verify units without symlinking or enabling"
#
# install.sh — idempotent. Symlinks the wrapper + units into place, verifies, and
# (only with --enable) turns the timer on. Safe to re-run; `git pull` updates the
# live units via the symlinks after a daemon-reload.
# Run standalone: ./install.sh   (then ./install.sh --enable when ready)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
units_dir="$HOME/.config/systemd/user"
bin_dir="$HOME/.local/bin"
state_dir="$HOME/threadwatch"

if [ -n "${usage_dry_run:-}" ]; then
    systemd-analyze --user verify "$here/threadwatch.service" || true
    echo "dry-run: verified units, nothing installed"
    exit 0
fi

mkdir -p "$units_dir" "$bin_dir" "$state_dir"

# Seed the watchlist on first install only (real config lives outside the repo).
if [ ! -f "$state_dir/.threadwatch.toml" ]; then
    cp "$here/.threadwatch.toml.example" "$state_dir/.threadwatch.toml"
    echo "seeded $state_dir/.threadwatch.toml (edit it)"
fi

ln -sf "$here/threadwatch"          "$bin_dir/threadwatch"
chmod +x "$here/threadwatch"
ln -sf "$here/threadwatch.timer"    "$units_dir/threadwatch.timer"
ln -sf "$here/threadwatch.service"  "$units_dir/threadwatch.service"

systemctl --user daemon-reload
systemd-analyze --user verify "$units_dir/threadwatch.service"
echo "installed. sandbox score: systemd-analyze security --user threadwatch.service"

if [ -n "${usage_enable:-}" ]; then
    systemctl --user enable --now threadwatch.timer
    systemctl --user list-timers threadwatch.timer
else
    echo "not enabled. run: systemctl --user enable --now threadwatch.timer  (or re-run with --enable)"
fi
