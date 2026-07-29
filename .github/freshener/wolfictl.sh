#!/usr/bin/env bash
# Update the wolfictl package from the Go module proxy and the release
# checksums file.
#
# Version discovery uses proxy.golang.org rather than the GitHub releases API,
# because the proxy needs no token and has no practical rate limit. The proxy
# tracks Git tags, so a tag can appear there days before the release assets are
# published; the checksums fetch below is what confirms the binaries exist.
#
# Move 2 note: nix-update cannot drive this as-is because one file holds four
# per-platform sums in a lookup table.
set -euo pipefail

PKG_NIX="pkgs/wolfictl/default.nix"

PLATFORMS=(
  darwin_amd64
  darwin_arm64
  linux_amd64
  linux_arm64
)

current=$(awk '/^  version = "/ { match($0, /version = "([^"]+)"/, arr); print arr[1]; exit }' "$PKG_NIX")
latest=$(curl -fsSL "https://proxy.golang.org/github.com/wolfi-dev/wolfictl/@latest" | jq -r '.Version' | sed 's/^v//')

if [[ -z "$current" ]]; then
  echo "❌ Could not determine current wolfictl version"
  exit 1
fi
if [[ -z "$latest" || "$latest" == "null" ]]; then
  echo "❌ Could not determine latest wolfictl version"
  exit 1
fi

echo "Current wolfictl: ${current}"
echo "Latest wolfictl:  ${latest}"

if [[ "$current" == "$latest" ]]; then
  echo "✅ wolfictl is up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

# Upstream signs and publishes every binary's SHA256 in one file, so read the
# sums from there instead of downloading four binaries to prefetch them.
checksums_url="https://github.com/wolfi-dev/wolfictl/releases/download/v${latest}/wolfictl_checksums.txt"
echo "⬇️  Fetching checksums: ${checksums_url}"
if ! checksums=$(curl -fsSL "$checksums_url"); then
  echo "⏭️  Tag v${latest} exists but its release assets are not published yet"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

sed -i "s|^  version = \".*\"|  version = \"${latest}\"|" "$PKG_NIX"

for platform in "${PLATFORMS[@]}"; do
  asset="wolfictl_${platform}_${latest}_${platform}"
  sum=$(awk -v want="$asset" '$2 == want { print $1; exit }' <<< "$checksums")
  if [[ -z "$sum" ]]; then
    echo "❌ No checksum published for ${asset}"
    exit 1
  fi
  echo "🔑 ${platform}: ${sum}"
  sed -i "s|^\( *\"${platform}\" = \"\)[0-9a-f]*\"|\1${sum}\"|" "$PKG_NIX"
done

echo "✅ Updated ${PKG_NIX}"
git diff "$PKG_NIX"

{
  echo "updated=true"
  echo "version=${latest}"
  echo "files=${PKG_NIX}"
} >> "$GITHUB_OUTPUT"
