# Release contract (CI ⇄ router updater)

- Tag: `v<upstream version>`, e.g. `v1.104.7` (upstream Tailscale stable tag, same number). One release per upstream version.
- Assets (fixed names, version lives in the tag):
  - `tailscaled-linux-arm64` (tested), `tailscaled-linux-arm` (GOARM=7), `tailscaled-linux-mipsle`, `tailscaled-linux-mips` (GOMIPS=softfloat); the last three are untested and may be missing if their build failed.
    Each is one multicall "box" binary (tailscaled with the CLI included: `tailscale` is a symlink to it).
  - `SHA256SUMS`: `sha256sum` format (`<hex>  <name>`), covering every binary and `release.env`.
  - `release.env`: plain `KEY=value` lines, no quoting except where shown, parsed (never sourced) by the updater:
    ```
    TBU_VERSION=1.104.7
    TBU_UPSTREAM_COMMIT=<40-hex upstream commit>
    TBU_PUBLISHED=<unix epoch seconds when CI published the release>
    TBU_ARCHES=arm64 arm mipsle mips
    TBU_TESTED_ARCHES=arm64
    ```
- The updater reads `https://github.com/nurockplayer/tailbox-updater/releases/latest/download/release.env`, then fetches everything else from `.../releases/download/v<TBU_VERSION>/<asset>`.
- CI publishes as soon as upstream ships; the 48 h delay is applied by the router (`TBU_PUBLISHED`).
