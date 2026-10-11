#!/usr/bin/env bash
# Update herdr-telegram-agents from the latest stable GitHub release.
set -euo pipefail

PKG_NIX="pkgs/herdr-telegram-agents/default.nix"

current=$(awk '/^  version = "/ { sub(/^  version = "/, ""); sub(/".*/, ""); print; exit }' "$PKG_NIX")
latest=$(curl -fsSL "https://api.github.com/repos/permgps/herdr-telegram-agents/releases/latest" |
	jq -r '.tag_name' |
	sed 's/^v//')

if [[ -z "$current" ]]; then
	echo "❌ Could not determine current herdr-telegram-agents version"
	exit 1
fi
if [[ -z "$latest" || "$latest" == "null" ]]; then
	echo "❌ Could not determine latest herdr-telegram-agents version"
	exit 1
fi

echo "Current herdr-telegram-agents: ${current}"
echo "Latest herdr-telegram-agents:  ${latest}"

if [[ "$current" == "$latest" ]]; then
	echo "✅ herdr-telegram-agents is up to date"
	echo "updated=false" >>"$GITHUB_OUTPUT"
	exit 0
fi

nix run nixpkgs#nix-update -- --flake herdr-telegram-agents --version "$latest" --build

echo "✅ Updated ${PKG_NIX}"
git diff "$PKG_NIX"

{
	echo "updated=true"
	echo "version=${latest}"
	echo "files=${PKG_NIX}"
} >>"$GITHUB_OUTPUT"
