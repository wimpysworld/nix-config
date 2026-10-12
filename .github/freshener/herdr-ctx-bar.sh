#!/usr/bin/env bash
# Update herdr-ctx-bar from the latest stable GitHub release.
set -euo pipefail

PKG_NIX="pkgs/herdr-ctx-bar/default.nix"

current=$(awk '/^  version = "/ { sub(/^  version = "/, ""); sub(/".*/, ""); print; exit }' "$PKG_NIX")
latest=$(curl -fsSL "https://api.github.com/repos/pdalinis/herdr-ctx-bar/releases/latest" |
	jq -r '.tag_name' |
	sed 's/^v//')

if [[ -z "$current" ]]; then
	echo "❌ Could not determine current herdr-ctx-bar version"
	exit 1
fi
if [[ -z "$latest" || "$latest" == "null" ]]; then
	echo "❌ Could not determine latest herdr-ctx-bar version"
	exit 1
fi

echo "Current herdr-ctx-bar: ${current}"
echo "Latest herdr-ctx-bar:  ${latest}"

if [[ "$current" == "$latest" ]]; then
	echo "✅ herdr-ctx-bar is up to date"
	echo "updated=false" >>"$GITHUB_OUTPUT"
	exit 0
fi

nix run nixpkgs#nix-update -- --flake herdr-ctx-bar --version "$latest" --build

echo "✅ Updated ${PKG_NIX}"
git diff "$PKG_NIX"

{
	echo "updated=true"
	echo "version=${latest}"
	echo "files=${PKG_NIX}"
} >>"$GITHUB_OUTPUT"
