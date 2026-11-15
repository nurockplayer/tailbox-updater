# Acceptance

| # | Row | How to judge | Status |
|---|-----|--------------|--------|
| A1 | CI builds the arm64 box binary from the newest upstream stable tag the day it appears, under the size budget | Actions run log + release assets | open |
| A2 | Each release has SHA256SUMS, release.env and a GitHub artifact attestation | `gh attestation verify tailscaled-linux-arm64 --repo nurockplayer/tailbox-updater` | open |
| A3 | Updater on the AXT1800 does nothing when already current, and waits until a release is 48 h old | `tailbox-update status`, logread | open |
| A4 | Updater on the AXT1800 swaps to a newer release and Tailscale is Running afterwards (exit node + routes work) | `tailscale status`, phone via exit node | open |
| A5 | A release that fails the health check is rolled back automatically and not retried | forced bad release test, logread | open |
| A6 | Boot check restores a working binary when Tailscale is not healthy after boot | boot-check test, logread | open |
| A7 | `install.sh` one-liner installs cron + boot hook; `uninstall` removes them | crontab, /etc/rc.local | open |
| A8 | README: install, removed features, rollback, verifying binaries, unofficial disclaimer, untested arches | read | open |
