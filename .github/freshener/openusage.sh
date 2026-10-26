#!/usr/bin/env bash
# Update OpenUsage from the latest stable GitHub release.
set -euo pipefail

PKG_NIX="pkgs/openusage/default.nix"
REPOSITORY="https://github.com/janekbaraniewski/openusage"

current=$(awk '/^  version = "/ { match($0, /version = "([^"]+)"/, arr); print arr[1]; exit }' "$PKG_NIX")
release=$(curl -fsSL "https://api.github.com/repos/janekbaraniewski/openusage/releases/latest")
latest=$(jq -er 'select(.draft == false and .prerelease == false) | .tag_name' <<< "$release")
latest=${latest#v}

if [[ -z "$current" || ! "$latest" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Could not determine the current or latest stable OpenUsage version" >&2
  exit 1
fi

echo "Current OpenUsage: ${current}"
echo "Latest OpenUsage:  ${latest}"

if [[ "$current" == "$latest" ]]; then
  echo "OpenUsage is up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

declare -A archives=(
  [x86_64-linux]=linux_amd64
  [aarch64-linux]=linux_arm64
  [x86_64-darwin]=darwin_amd64
  [aarch64-darwin]=darwin_arm64
)

# Fetch every archive before changing the version or any hash.
edits=(-e "s|^  version = \".*\"|  version = \"${latest}\"|")
for platform in x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin; do
  archive="openusage_${latest}_${archives[$platform]}.tar.gz"
  jq -e --arg name "$archive" 'any(.assets[]; .name == $name and .state == "uploaded")' <<< "$release" > /dev/null
  url="${REPOSITORY}/releases/download/v${latest}/${archive}"
  echo "Fetching ${platform}: ${url}"
  hash=$(nix store prefetch-file --json --hash-type sha256 "$url" | jq -er '.hash')
  if [[ ! "$hash" =~ ^sha256-[A-Za-z0-9+/]{43}=$ ]]; then
    echo "Invalid SHA-256 hash for ${archive}" >&2
    exit 1
  fi
  edits+=(-e "/${platform} = fetchurl {/,/};/s|hash = \".*\"|hash = \"${hash}\"|")
done

sed -i "${edits[@]}" "$PKG_NIX"
echo "Updated ${PKG_NIX}"
git diff -- "$PKG_NIX"

{
  echo "updated=true"
  echo "version=${latest}"
  echo "files=${PKG_NIX}"
} >> "$GITHUB_OUTPUT"
