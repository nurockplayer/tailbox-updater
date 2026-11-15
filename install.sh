#!/bin/sh
set -e
raw=${TBU_RAW_URL:-https://raw.githubusercontent.com/nurockplayer/tailbox-updater/main}
bin=${TBU_INSTALL_BIN:-/usr/bin/tailbox-update}
conf=${TBU_CONF:-/etc/tailbox-updater.conf}
if [ "${1:-}" = uninstall ]; then
    if [ -x "$bin" ]; then "$bin" remove-hooks; fi
    rm -f "$bin" "$conf"
    echo 'Tailscale was left in place. To restore stock, run tailbox-update rollback before uninstall, or cp /rom/usr/sbin/tailscaled /usr/sbin/tailscaled.'
    exit 0
fi
mkdir -p "$(dirname "$bin")" "$(dirname "$conf")"
case $raw in
    file://*) cp "${raw#file://}/updater/tailbox-update" "$bin";;
    *) if command -v curl >/dev/null 2>&1; then curl -fsSL "$raw/updater/tailbox-update" -o "$bin"; elif command -v uclient-fetch >/dev/null 2>&1; then uclient-fetch -q -O "$bin" "$raw/updater/tailbox-update"; else wget -q -O "$bin" "$raw/updater/tailbox-update"; fi;;
esac
chmod 755 "$bin"
if [ ! -e "$conf" ]; then
    cat > "$conf" <<'CONF'
# TBU_REPO_URL=https://github.com/nurockplayer/tailbox-updater/releases
# TBU_MIN_AGE_H=48
# TBU_HEALTH_TIMEOUT=90
# TBU_BOOT_WAIT=120
CONF
fi
"$bin" install-hooks
"$bin" status
echo 'The first update happens at the cron time, or now with tailbox-update update --now.'
