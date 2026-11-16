# tailbox-updater

Unofficial, size-trimmed Tailscale builds and rollback-safe auto-updates for GL.iNet routers.

> Independent community project. Not affiliated with or endorsed by Tailscale Inc. or GL.iNet.

Tailscale is a trademark of Tailscale Inc. Builds use unmodified upstream Tailscale source; only build tags are removed.

## Install

Run either command on the router:

```sh
wget -qO- https://raw.githubusercontent.com/nurockplayer/tailbox-updater/main/install.sh | sh
```

```sh
curl -fsSL https://raw.githubusercontent.com/nurockplayer/tailbox-updater/main/install.sh | sh
```

The installer adds cron and boot hooks and reports updater status. To uninstall the updater and its hooks:

```sh
wget -qO- https://raw.githubusercontent.com/nurockplayer/tailbox-updater/main/install.sh | sh -s uninstall
```

Uninstall leaves Tailscale in place. To restore the stock router binary, first run `tailbox-update rollback`, or restore it by hand:

```sh
/etc/init.d/tailscale stop
rm -f /usr/sbin/tailscaled
cp /rom/usr/sbin/tailscaled /usr/sbin/tailscaled
/etc/init.d/tailscale start
```

Configuration is read from `/etc/tailbox-updater.conf`. The defaults are:

```sh
TBU_REPO_URL=https://github.com/nurockplayer/tailbox-updater/releases
TBU_MIN_AGE_H=48
TBU_HEALTH_TIMEOUT=90
TBU_BOOT_WAIT=120
```

## Updates

Releases are checked daily at 03:23 UTC. A release can also be built with the workflow's `version` input. The updater waits until a release is 48 hours old before applying it; `--now` bypasses that age wait. It never downgrades.

The updater checks the SHA256 checksum and binary version, checks free space, then swaps the binary and checks that Tailscale becomes healthy. If the health check fails, it restores the previous binary and records that release version in its failed list so it will not retry it. The boot check restores a working binary when Tailscale is unhealthy after startup.

Commands:

```text
tailbox-update status
tailbox-update update [--now] [--force]
tailbox-update rollback
tailbox-update boot-check
tailbox-update install-hooks
tailbox-update remove-hooks
```

`update` runs on the scheduled cron hook. `--force` permits retrying a recorded failed version; `--now` skips only the release age wait. `rollback` restores the saved previous binary, or the stock ROM binary if no previous copy is available.

## Builds and removed features

Each architecture gets one multicall box binary: `tailscaled` includes the CLI, and `tailscale` is a symlink to it. Build size budgets are 23,068,672 bytes for arm64 and arm, and 25,165,824 bytes for mipsle and mips.

arm64 is tested on the GL-AXT1800. arm, mipsle, and mips builds are compiled but **not tested on hardware**. A non-arm64 build may be absent if its build fails.

The build removes the following upstream feature tags. The feature is omitted from this binary, so its corresponding capability is unavailable:

| Feature tag | What you lose |
|---|---|
| `aws` | AWS integration support. |
| `bird` | BIRD routing-daemon integration. |
| `kube` | Kubernetes integration. |
| `tap` | TAP network-device support. |
| `capture` | Packet-capture support. |
| `ssh` | Tailscale SSH. |
| `drive` | Taildrive file sharing. |
| `taildrop` | Taildrop file transfer. |
| `webclient` | The web client. |
| `serve` | Tailscale Serve. |
| `acme` | ACME certificate support. |
| `appconnectors` | App connector support. |
| `synology` | Synology-specific integration. |
| `systray` | System tray integration. |
| `tpm` | TPM support. |
| `dbus` | D-Bus integration. |
| `networkmanager` | NetworkManager integration. |
| `resolved` | systemd-resolved integration. |
| `sdnotify` | systemd service notifications. |
| `desktop_sessions` | Desktop session integration. |
| `flashappliance` | Flash appliance integration. |
| `completion` | Shell completion support. |
| `completion_scripts` | Shell completion scripts. |
| `qrcodes` | QR code support. |
| `androidbin` | Android binary integration. |
| `androiddns` | Android DNS integration. |
| `cloud` | Cloud integration support. |
| `relayserver` | Running a relay server. |
| `outboundproxy` | Outbound proxy support. |
| `conn25` | Connection type 25 support. |
| `identityfederation` | Identity federation. |
| `oauthkey` | OAuth key support. |
| `posture` | Device posture checks. |
| `netlog` | Network logging. |
| `doctor` | The diagnostic doctor command. |
| `debugeventbus` | Debug event bus support. |
| `debugportmapper` | Port mapper debugging support. |
| `clientupdate` | Tailscale client self-update support. |
| `syspolicy` | System policy support. |
| `serviceclientprefs` | Service client preferences. |
| `colorable` | Color terminal output support. |
| `favorites` | Favorites support. |
| `remoteconfig` | Remote configuration support. |
| `hujsonconf` | HUJSON configuration support. |
| `dnsresolvecache` | DNS resolve cache support. |
| `cachenetmap` | Network map cache support. |
| `linuxdnsfight` | Linux DNS conflict handling. |

## Verify release files

Check the downloaded files against the published checksums:

```sh
sha256sum -c SHA256SUMS
```

Verify the GitHub artifact attestation for a binary (repeat with another asset name as needed):

```sh
gh attestation verify tailscaled-linux-arm64 --repo nurockplayer/tailbox-updater
```

Each release includes `tailscaled-linux-<arch>` assets that built successfully, `SHA256SUMS`, and `release.env`. The release attests each binary and `release.env`. `release.env` records the upstream version and commit, publication time, available architectures, and tested architectures.

## Rollback

```sh
tailbox-update rollback
```

The updater restores its saved previous binary. If that copy is unavailable, it uses the stock ROM copy at `/rom/usr/sbin/tailscaled`. To restore stock by hand, use the stop / copy / start commands in the install section.

## Known limitations

- [Issue #4](https://github.com/nurockplayer/tailbox-updater/issues/4)
- [Issue #5](https://github.com/nurockplayer/tailbox-updater/issues/5)
