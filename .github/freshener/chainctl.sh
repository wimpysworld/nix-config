#!/usr/bin/env bash
# Update the chainctl package from Chainguard's release metadata.
#
# Move 2 note: nix-update cannot drive this as-is because one file holds three
# per-platform sources under passthru.sources, each with its own hash.
set -euo pipefail

PKG_NIX="pkgs/chainctl/default.nix"

METADATA="https://dl.enforce.dev/chainctl/latest/metadata.json"

current=$(awk '/^  version = "/ { match($0, /version = "([^"]+)"/, arr); print arr[1]; exit }' "$PKG_NIX")
latest=$(curl -fsSL "$METADATA" | jq -r '.version')

if [[ -z "$current" ]]; then
  echo "❌ Could not determine current chainctl version"
  exit 1
fi
if [[ -z "$latest" || "$latest" == "null" ]]; then
  echo "❌ Could not determine latest chainctl version"
  exit 1
fi

echo "Current chainctl: ${current}"
echo "Latest chainctl:  ${latest}"

if [[ "$current" == "$latest" ]]; then
  echo "✅ chainctl is up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

# Each entry maps the Nix attribute name to the published binary name.
declare -A binaries=(
  [x86_64-linux]=chainctl_linux_x86_64
  [aarch64-linux]=chainctl_linux_arm64
  [aarch64-darwin]=chainctl_darwin_arm64
)

sed -i "s|^  version = \".*\"|  version = \"${latest}\"|" "$PKG_NIX"

for platform in "${!binaries[@]}"; do
  url="https://dl.enforce.dev/chainctl/${latest}/${binaries[$platform]}"
  echo "⬇️  Fetching ${platform}: ${url}"
  hash=$(nix store prefetch-file --json --hash-type sha256 "$url" | jq -r '.hash')
  sed -i "/${platform} = fetchurl {/,/};/s|hash = \".*\"|hash = \"${hash}\"|" "$PKG_NIX"
done

echo "✅ Updated ${PKG_NIX}"
git diff "$PKG_NIX"

{
  echo "updated=true"
  echo "version=${latest}"
  echo "files=${PKG_NIX}"
} >> "$GITHUB_OUTPUT"
