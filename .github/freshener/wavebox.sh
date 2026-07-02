#!/usr/bin/env bash
# Update the Wavebox package from the vendor's release metadata.
#
# Move 2 note: nix-update cannot drive this as-is because the file holds two
# sub-derivations (linux and darwin), each with its own version and hash. Either
# keep this bespoke script or split the platforms so nix-update can target them.
set -euo pipefail

PKG_NIX="pkgs/wavebox/default.nix"

LINUX_JSON="https://download.wavebox.app/stable/linux/latest.json"
DARWIN_JSON="https://download.wavebox.app/stable/macuniversal/latest.json"

current_linux=$(awk '/^  linux = stdenvNoCC.mkDerivation/,/^  \}\);/ { if ($0 ~ /version = "/) { match($0, /version = "([^"]+)"/, arr); print arr[1]; exit } }' "$PKG_NIX")
current_darwin=$(awk '/^  darwin = stdenvNoCC.mkDerivation/,/^  \}\);/ { if ($0 ~ /version = "/) { match($0, /version = "([^"]+)"/, arr); print arr[1]; exit } }' "$PKG_NIX")

echo "Current Linux:  ${current_linux}"
echo "Current Darwin: ${current_darwin}"

latest_linux=$(curl -fsSL "$LINUX_JSON" | jq -r '.urls.deb | match("wavebox_(.+)_amd64\\.deb").captures[0].string')
latest_darwin=$(curl -fsSL "$DARWIN_JSON" | jq -r '.url | match("Install%20Wavebox%20(.+)\\.dmg").captures[0].string')

if [[ -z "$latest_linux" || "$latest_linux" == "null" || -z "$latest_darwin" || "$latest_darwin" == "null" ]]; then
  echo "❌ Could not determine latest Wavebox version"
  exit 1
fi

echo "Latest Linux:   ${latest_linux}"
echo "Latest Darwin:  ${latest_darwin}"

if [[ "$current_linux" == "$latest_linux" && "$current_darwin" == "$latest_darwin" ]]; then
  echo "✅ Wavebox is up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

linux_url="https://download.wavebox.app/stable/linux/deb/amd64/wavebox_${latest_linux}_amd64.deb"
echo "⬇️  Fetching Linux deb: ${linux_url}"
linux_hash=$(nix store prefetch-file --json --hash-type sha256 "$linux_url" | jq -r '.hash')

darwin_url="https://download.wavebox.app/stable/macuniversal/Install%20Wavebox%20${latest_darwin}.dmg"
echo "⬇️  Fetching Darwin dmg: ${darwin_url}"
darwin_hash=$(nix store prefetch-file --json --hash-type sha256 --name wavebox.dmg "$darwin_url" | jq -r '.hash')

sed -i "/^  linux = stdenvNoCC.mkDerivation/,/^  });/s/version = \".*\"/version = \"${latest_linux}\"/" "$PKG_NIX"
sed -i "/^  linux = stdenvNoCC.mkDerivation/,/^  });/s|hash = \".*\"|hash = \"${linux_hash}\"|" "$PKG_NIX"
sed -i "/^  darwin = stdenvNoCC.mkDerivation/,/^  });/s/version = \".*\"/version = \"${latest_darwin}\"/" "$PKG_NIX"
sed -i "/^  darwin = stdenvNoCC.mkDerivation/,/^  });/s|hash = \".*\"|hash = \"${darwin_hash}\"|" "$PKG_NIX"

echo "✅ Updated ${PKG_NIX}"
git diff "$PKG_NIX"

{
  echo "updated=true"
  echo "version=${latest_linux}"
  echo "files=${PKG_NIX}"
} >> "$GITHUB_OUTPUT"
