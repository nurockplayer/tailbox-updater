#!/bin/sh
set -u
root=$(mktemp -d); trap 'rm -rf "$root"' EXIT
TBU_ROOT=$root; export TBU_ROOT
cron_before=$(if [ -e /etc/init.d/cron ]; then sha256sum /etc/init.d/cron; else echo absent; fi)
mkdir -p "$root/etc/init.d" "$root/bin" "$root/rom" "$root/work" "$root/state" "$root/releases/latest/download" "$root/releases/download" "$root/etc"
cat > "$root/etc/init.d/cron" <<'CRON'
#!/bin/sh
exit 0
CRON
chmod +x "$root/etc/init.d/cron"
cat > "$root/bin/logger" <<'LOGGER'
#!/bin/sh
exit 0
LOGGER
chmod +x "$root/bin/logger"
PATH="$root/bin:$PATH"; export PATH
TBU_CONF=$root/etc/conf TBU_BIN=$root/bin/tailscaled TBU_CLI=$root/bin/tailscale TBU_ROM_BIN=$root/rom/tailscaled TBU_INIT=$root/init TBU_STATE=$root/state TBU_WORK=$root/work TBU_CRONTAB=$root/etc/crontab TBU_RCLOCAL=$root/etc/rc.local TBU_ARCH=arm64 TBU_HEALTH_TIMEOUT=0 TBU_BOOT_WAIT=0 TBU_REPO_URL=file://$root/releases
export TBU_CONF TBU_BIN TBU_CLI TBU_ROM_BIN TBU_INIT TBU_STATE TBU_WORK TBU_CRONTAB TBU_RCLOCAL TBU_ARCH TBU_HEALTH_TIMEOUT TBU_BOOT_WAIT TBU_REPO_URL
cat > "$root/init" <<'INIT'
#!/bin/sh
exit 0
INIT
chmod +x "$root/init"
echo 'exit 0' > "$TBU_RCLOCAL"
makebin() {
    cat > "$1" <<BIN
#!/bin/sh
if [ "\$1" = --version ]; then echo '$2'; exit; fi
if [ -f '$root/bad-$2' ]; then echo '{"BackendState":"Stopped"}'; else echo '{"BackendState":"Running"}'; fi
BIN
    chmod +x "$1"
}
makebin "$TBU_ROM_BIN" 1.0.0
cp "$TBU_ROM_BIN" "$TBU_BIN"; ln -s tailscaled "$TBU_CLI"
release() {
    v=$1; pub=$2; actual=${3:-$1}; dir=$root/releases/download/v$v
    mkdir -p "$dir"
    makebin "$dir/tailscaled-linux-arm64" "$actual"
    (cd "$dir" && sha256sum tailscaled-linux-arm64 > SHA256SUMS)
    printf 'TBU_VERSION=%s\nTBU_PUBLISHED=%s\nTBU_ARCHES=arm64\nTBU_TESTED_ARCHES=arm64\n' "$v" "$pub" > "$root/releases/latest/download/release.env"
}
run() { sh updater/tailbox-update "$@"; }
failed=0
check() { if "$@"; then echo "PASS $name"; else echo "FAIL $name"; failed=1; fi; }
isver() { [ "$("$TBU_BIN" --version)" = "$1" ]; }
now=$(date +%s); old=$((now-200000))
release 1.0.0 "$old"; run update --foreground >/dev/null; name=current; check isver 1.0.0
release 1.1.0 "$now"; run update --foreground >/dev/null; name=delay; check isver 1.0.0
run update --now --foreground >/dev/null; name=install; check sh -c '[ "$("$TBU_BIN" --version)" = 1.1.0 ] && [ "$(cat "$TBU_STATE/installed")" = 1.1.0 ] && [ -L "$TBU_CLI" ]'
release 1.2.0 "$old"; echo bad > "$root/releases/download/v1.2.0/SHA256SUMS"; run update --foreground >/dev/null || :; name=checksum; check isver 1.1.0
release 1.2.0 "$old" 9.9.9; run update --foreground >/dev/null || :; name=version; check isver 1.1.0
release 1.2.0 "$old"; touch "$root/bad-1.2.0"; run update --foreground >/dev/null || :; name=rollback; check sh -c '[ "$("$TBU_BIN" --version)" = 1.1.0 ] && grep -qx 1.2.0 "$TBU_STATE/failed"'
rm "$root/bad-1.2.0"; run update --foreground >/dev/null; name=failed_skip; check isver 1.1.0
release 1.0.0 "$old"; run update --force --foreground >/dev/null; name=no_downgrade; check isver 1.1.0
printf 'TBU_VERSION=$(touch %s/pwned)\nTBU_PUBLISHED=1\nTBU_ARCHES=arm64\n' "$root" > "$root/releases/latest/download/release.env"; run update --foreground >/dev/null || :; name=malicious; check test ! -e "$root/pwned"
release 1.2.1 "$old"; TBU_TEST_AVAIL_KB=1 run update --foreground >/dev/null || :; name=space; check isver 1.1.0
touch "$root/bad-1.1.0"; run boot-check >/dev/null; name=boot; check isver 1.0.0
run install-hooks; first=$(cat "$TBU_CRONTAB"); run install-hooks; name=hooks; check sh -c '[ "$(wc -l < "$TBU_CRONTAB")" -eq 1 ] && [ "$(grep -c tailbox-updater "$TBU_RCLOCAL")" -eq 1 ] && [ "$(tail -n 1 "$TBU_RCLOCAL")" = "exit 0" ]'; name=minute; check test "$first" = "$(cat "$TBU_CRONTAB")"
run remove-hooks; name=remove; check sh -c '! grep -q tailbox-updater "$TBU_CRONTAB" && ! grep -q tailbox-updater "$TBU_RCLOCAL"'
TBU_RAW_URL=file://$(pwd) TBU_INSTALL_BIN=$root/bin/installed; export TBU_RAW_URL TBU_INSTALL_BIN
sh install.sh >/dev/null; sh install.sh uninstall >/dev/null; name=installer; check test ! -e "$TBU_INSTALL_BIN"
cron_after=$(if [ -e /etc/init.d/cron ]; then sha256sum /etc/init.d/cron; else echo absent; fi)
name=system_cron_untouched; check test "$cron_before" = "$cron_after"
exit "$failed"
