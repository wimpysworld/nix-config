#!/usr/bin/env bash
# Update Moltis from the latest stable GitHub release.
set -euo pipefail

PKG_NIX="pkgs/moltis/default.nix"
REPOSITORY="https://github.com/moltis-org/moltis"

current=$(awk '/^  version = "/ { match($0, /version = "([^"]+)"/, arr); print arr[1]; exit }' "$PKG_NIX")
release=$(curl -fsSL "https://api.github.com/repos/moltis-org/moltis/releases/latest")
latest=$(jq -er 'select(.draft == false and .prerelease == false) | .tag_name' <<< "$release")
latest=${latest#v}

if [[ -z "$current" || ! "$latest" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  echo "Could not determine the current or latest stable Moltis version" >&2
  exit 1
fi

echo "Current Moltis: ${current}"
echo "Latest Moltis:  ${latest}"

if [[ "$current" == "$latest" ]]; then
  echo "Moltis is up to date"
  echo "updated=false" >> "${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi

archive="moltis-${latest}-x86_64-unknown-linux-gnu.tar.gz"
jq -e --arg name "$archive" 'any(.assets[]; .name == $name and .state == "uploaded")' <<< "$release" > /dev/null
url="${REPOSITORY}/releases/download/${latest}/${archive}"
echo "Fetching x86_64-linux: ${url}"
hash=$(nix store prefetch-file --json --hash-type sha256 "$url" | jq -er '.hash')
if [[ ! "$hash" =~ ^sha256-[A-Za-z0-9+/]{43}=$ ]]; then
  echo "Invalid SHA-256 hash for ${archive}" >&2
  exit 1
fi

sed -i \
  -e "s|^  version = \".*\"|  version = \"${latest}\"|" \
  -e "/src = fetchurl {/,/};/s|hash = \".*\"|hash = \"${hash}\"|" \
  "$PKG_NIX"
echo "Updated ${PKG_NIX}"
git diff -- "$PKG_NIX"

{
  echo "updated=true"
  echo "version=${latest}"
  echo "files=${PKG_NIX}"
} >> "${GITHUB_OUTPUT:-/dev/null}"
