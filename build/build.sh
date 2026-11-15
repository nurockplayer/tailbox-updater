#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
version=${1:?usage: build.sh version arch}
arch=${2:?usage: build.sh version arch}
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid version: $version" >&2; exit 1; }
case "$arch" in
  arm64) goarch=arm64 ;;
  arm) goarch=arm; export GOARM=7 ;;
  mipsle|mips) goarch="$arch"; export GOMIPS=softfloat ;;
  *) echo "Invalid architecture: $arch" >&2; exit 1 ;;
esac
src="$root/work/tailscale-$version"
mkdir -p "$root/work" "$root/dist"
if [[ ! -d $src ]]; then
  git clone --depth 1 --branch "v$version" https://github.com/tailscale/tailscale "$src"
fi
cd "$src"
if [[ $(git rev-parse HEAD) != "$(git rev-parse "refs/tags/v$version^{commit}")" ]]; then
  echo "Existing checkout is not at v$version: $src" >&2
  exit 1
fi
known=$(./tool/go run ./cmd/featuretags --list | awk '{sub(/:$/, "", $1); print $1}')
features=()
while IFS= read -r feature || [[ -n $feature ]]; do
  [[ -z $feature || $feature == \#* ]] && continue
  if grep -Fxq -- "$feature" <<< "$known"; then
    features+=("$feature")
  else
    echo "Warning: upstream does not know feature $feature; skipping" >&2
  fi
done < "$root/build/remove-features.txt"
list=$(IFS=,; echo "${features[*]}")
OMIT=$(./tool/go run ./cmd/featuretags --remove="$list")
asset="tailscaled-linux-$arch"
GOOS=linux GOARCH="$goarch" CGO_ENABLED=0 TS_USE_TOOLCHAIN=1 TAGS="ts_include_cli,$OMIT" ./build_dist.sh --strip -o "$root/dist/$asset" ./cmd/tailscaled
size=$(wc -c < "$root/dist/$asset" | tr -d ' ')
budget=$(awk -v arch="$arch" '$1 == arch {print $2}' "$root/build/size-budget.tsv")
echo "$asset: $size bytes (budget $budget bytes)"
if (( size > budget )); then
  echo "Size budget exceeded for $arch: $size > $budget bytes" >&2
  exit 3
fi
git rev-parse HEAD > "$root/dist/$asset.commit"
