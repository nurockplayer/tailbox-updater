#!/bin/sh
# The test invokes functions indirectly and passes literal scripts to sh -c.
# shellcheck disable=SC2016,SC2317
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
cat > "$root/bin/uci" <<'UCI'
#!/bin/sh
[ -f "$TBU_ROOT/uci-enabled" ] || exit 1
cat "$TBU_ROOT/uci-enabled"
UCI
chmod +x "$root/bin/uci"
# A full overlay: staging a binary beside the installed one fails like ENOSPC.
cat > "$root/bin/cp" <<CP
#!/bin/sh
for last do :; done
case \$last in *.tbu-new) if [ -e '$root/full' ]; then echo 'No space left on device' >&2; exit 1; fi;; esac
exec /bin/cp "\$@"
CP
chmod +x "$root/bin/cp"
PATH="$root/bin:$PATH"; export PATH
TBU_CONF=$root/etc/conf TBU_BIN=$root/bin/tailscaled TBU_CLI=$root/bin/tailscale TBU_ROM_BIN=$root/rom/tailscaled TBU_INIT=$root/init TBU_STATE=$root/state TBU_WORK=$root/work TBU_CRONTAB=$root/etc/crontab TBU_RCLOCAL=$root/etc/rc.local TBU_ARCH=arm64 TBU_HEALTH_TIMEOUT=0 TBU_BOOT_WAIT=0 TBU_REPO_URL=file://$root/releases
export TBU_CONF TBU_BIN TBU_CLI TBU_ROM_BIN TBU_INIT TBU_STATE TBU_WORK TBU_CRONTAB TBU_RCLOCAL TBU_ARCH TBU_HEALTH_TIMEOUT TBU_BOOT_WAIT TBU_REPO_URL
cat > "$root/init" <<'INIT'
#!/bin/sh
[ "$1" != enabled ] || [ ! -e "$TBU_ROOT/disabled" ]
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
touch "$root/bad-1.1.0" "$root/disabled"; run boot-check > "$root/boot.log"; name=boot_disabled; check sh -c '[ "$("$TBU_BIN" --version)" = 1.1.0 ] && grep -q "boot-check skipped" "$TBU_ROOT/boot.log"'
rm "$root/disabled"; echo 0 > "$root/uci-enabled"; run boot-check > "$root/boot.log"; name=boot_uci_disabled; check sh -c '[ "$("$TBU_BIN" --version)" = 1.1.0 ] && grep -q "boot-check skipped" "$TBU_ROOT/boot.log"'
echo 1 > "$root/uci-enabled"; run boot-check >/dev/null; name=boot_uci_enabled; check isver 1.0.0
makebin "$TBU_BIN" 1.1.0; rm "$root/uci-enabled"; run boot-check >/dev/null; name=boot_uci_missing; check isver 1.0.0
rm "$root/bad-1.1.0"; up=$root/overlay/upper${TBU_BIN#"$root"}; mkdir -p "$(dirname "$up")"; cp "$TBU_BIN" "$up"; dd if=/dev/zero bs=1024 count=2048 >> "$up" 2>/dev/null
release 1.2.1 "$old"; TBU_TEST_BIN_AVAIL_KB=1 run update --foreground >/dev/null || :; name=rom_copy_space; check isver 1.2.1
release 1.2.2 "$old"; rm "$up"; touch "$root/full"; run update --foreground >/dev/null || :; name=full_rom_only; check sh -c '[ "$("$TBU_BIN" --version)" = 1.2.1 ] && [ ! -e "$TBU_BIN.tbu-new" ] && ! grep -qx 1.2.2 "$TBU_STATE/failed"'
cp "$TBU_BIN" "$up"; run update --foreground >/dev/null; name=full_held; check isver 1.2.2; rm "$root/full"
rm "$up"; dd if=/dev/zero bs=1024 count=4096 >> "$TBU_BIN" 2>/dev/null; release 1.2.3 "$old"; TBU_TEST_BIN_AVAIL_KB=3072 run update --foreground >/dev/null || :; name=rom_only_rollback_space; check isver 1.2.2
makebin "$TBU_BIN" 1.96.4-tiny.by.admon.1266; release 1.96.5 "$old"; run update --foreground >/dev/null; name=suffix_install; check sh -c '[ "$("$TBU_BIN" --version)" = 1.96.5 ] && [ "$(cat "$TBU_WORK/prev.version")" = 1.96.4-tiny.by.admon.1266 ]'
makebin "$TBU_BIN" 1.96.4-tiny.by.admon.1266; release 1.96.4 "$old"; run update --foreground > "$root/version.log"; name=suffix_equal; check sh -c 'grep -q "up to date" "$TBU_ROOT/version.log" && [ "$("$TBU_BIN" --version)" = 1.96.4-tiny.by.admon.1266 ]'
makebin "$TBU_BIN" garbage; run update --foreground > "$root/version.log" || :; name=invalid_version; check grep -q 'invalid installed version' "$root/version.log"
run install-hooks; first=$(cat "$TBU_CRONTAB"); run install-hooks; name=hooks; check sh -c '[ "$(wc -l < "$TBU_CRONTAB")" -eq 1 ] && [ "$(grep -c tailbox-updater "$TBU_RCLOCAL")" -eq 1 ] && [ "$(tail -n 1 "$TBU_RCLOCAL")" = "exit 0" ]'; name=hook_paths; self=$(pwd)/updater/tailbox-update; check sh -c 'grep -Fq "$1 update # tailbox-updater" "$TBU_CRONTAB" && grep -Fq "$1 boot-check" "$TBU_RCLOCAL"' sh "$self"; name=minute; check test "$first" = "$(cat "$TBU_CRONTAB")"
run remove-hooks; name=remove; check sh -c '! grep -q tailbox-updater "$TBU_CRONTAB" && ! grep -q tailbox-updater "$TBU_RCLOCAL"'
TBU_RAW_URL=file://$(pwd) TBU_INSTALL_BIN=$root/bin/installed; export TBU_RAW_URL TBU_INSTALL_BIN
sh install.sh >/dev/null; sh install.sh uninstall >/dev/null; name=installer; check test ! -e "$TBU_INSTALL_BIN"
cron_after=$(if [ -e /etc/init.d/cron ]; then sha256sum /etc/init.d/cron; else echo absent; fi)
name=system_cron_untouched; check test "$cron_before" = "$cron_after"
exit "$failed"
