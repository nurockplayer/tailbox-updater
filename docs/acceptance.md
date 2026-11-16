# Acceptance

| # | Row | How to judge | Status |
|---|-----|--------------|--------|
| A1 | CI builds the arm64 box binary from the newest upstream stable tag the day it appears, under the size budget | Actions run log + release assets | partial 2026-11-16: build + size budget pass (manual dispatch run 43805432058); scheduled pickup of a new upstream tag not yet observed |
| A2 | Each release has SHA256SUMS, release.env and a GitHub artifact attestation | `gh attestation verify tailscaled-linux-arm64 --repo nurockplayer/tailbox-updater` | pass 2026-11-16 (v1.104.7: SHA256SUMS OK, attestations verified for 4 binaries + release.env) |
| A3 | Updater on the AXT1800 does nothing when already current, and waits until a release is 48 h old | `tailbox-update status`, logread | pass 2026-11-16 (AXT: up to date; fresh 1.104.7 shown "due: no" until 48 h old) |
| A4 | Updater on the AXT1800 swaps to a newer release and Tailscale is Running afterwards (exit node + routes work) | `tailscale status`, phone via exit node | pass 2026-11-16 (AXT forced reinstall in 20 s, Running, exit node + routes offered; phone check through the exit node done after the first install) |
| A5 | A release that fails the health check is rolled back automatically and not retried | forced bad release test, logread | pass 2026-11-16 (fake 1.104.8 failed health, rolled back in 10 s, skipped on rerun) |
| A6 | Boot check restores a working binary when Tailscale is not healthy after boot | boot-check test, logread | pass 2026-11-16 (real reboot: healthy binary left untouched; overlay space bug found there fixed in #9) |
| A7 | `install.sh` one-liner installs cron + boot hook; `uninstall` removes them | crontab, /etc/rc.local | pass 2026-11-16 (install adds cron `0 4 * * *` + boot hook; uninstall removes only our lines; reinstalled from main 84aaac0) |
| A8 | README: install, removed features, rollback, verifying binaries, unofficial disclaimer, untested arches | read | pass 2026-11-16 (documented install, status and rollback commands used on the AXT) |
