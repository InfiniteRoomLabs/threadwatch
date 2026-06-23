#!/usr/bin/env bash
# install.sh -- idempotent. Symlinks the wrapper + units into place, verifies,
# and (with --enable) turns the timer on. Safe to re-run; `git pull` updates the
# live units via the symlinks after a daemon-reload.
#   --enable    also enable + start the timer (default: install + verify only)
#   --dry-run   verify units without symlinking or enabling
# Run standalone: ./install.sh        (then ./install.sh --enable when ready)
set -euo pipefail

enable=0; dry_run=0
for arg in "$@"; do
    case "$arg" in
        -e|--enable)  enable=1 ;;
        -n|--dry-run) dry_run=1 ;;
        -h|--help)    grep '^#' "$0" | sed 's/^# \?//'; exit 0 ;;
        *) echo "unknown arg: $arg" >&2; exit 64 ;;
    esac
done

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
units_dir="$HOME/.config/systemd/user"
bin_dir="$HOME/.local/bin"
state_dir="$HOME/threadwatch"

if [ "$dry_run" = 1 ]; then
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

if [ "$enable" = 1 ]; then
    systemctl --user enable --now threadwatch.timer
    systemctl --user list-timers threadwatch.timer
else
    echo "not enabled. run: systemctl --user enable --now threadwatch.timer  (or re-run with --enable)"
fi
