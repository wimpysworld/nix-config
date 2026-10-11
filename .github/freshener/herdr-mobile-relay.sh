#!/usr/bin/env bash
# Update herdr-mobile-relay from the latest stable GitHub release.
set -euo pipefail

PKG_NIX="pkgs/herdr-mobile-relay/default.nix"

current=$(awk '/^  version = "/ { sub(/^  version = "/, ""); sub(/".*/, ""); print; exit }' "$PKG_NIX")
latest=$(curl -fsSL "https://api.github.com/repos/0cv/herdr-mobile-relay/releases/latest" |
	jq -r '.tag_name' |
	sed 's/^v//')

if [[ -z "$current" ]]; then
	echo "❌ Could not determine current herdr-mobile-relay version"
	exit 1
fi
if [[ -z "$latest" || "$latest" == "null" ]]; then
	echo "❌ Could not determine latest herdr-mobile-relay version"
	exit 1
fi

echo "Current herdr-mobile-relay: ${current}"
echo "Latest herdr-mobile-relay:  ${latest}"

if [[ "$current" == "$latest" ]]; then
	echo "✅ herdr-mobile-relay is up to date"
	echo "updated=false" >>"$GITHUB_OUTPUT"
	exit 0
fi

nix run nixpkgs#nix-update -- --flake herdr-mobile-relay --version "$latest" --build

echo "✅ Updated ${PKG_NIX}"
git diff "$PKG_NIX"

{
	echo "updated=true"
	echo "version=${latest}"
	echo "files=${PKG_NIX}"
} >>"$GITHUB_OUTPUT"
