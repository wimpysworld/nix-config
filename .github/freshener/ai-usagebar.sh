#!/usr/bin/env bash
# Update ai-usagebar from the latest stable GitHub release.
set -euo pipefail

PKG_NIX="pkgs/ai-usagebar/default.nix"

current=$(awk '/^  version = "/ { sub(/^  version = "/, ""); sub(/".*/, ""); print; exit }' "$PKG_NIX")
latest=$(curl -fsSL "https://api.github.com/repos/akitaonrails/ai-usagebar/releases/latest" |
	jq -r '.tag_name' |
	sed 's/^v//')

if [[ -z "$current" ]]; then
	echo "❌ Could not determine current ai-usagebar version"
	exit 1
fi
if [[ -z "$latest" || "$latest" == "null" ]]; then
	echo "❌ Could not determine latest ai-usagebar version"
	exit 1
fi

echo "Current ai-usagebar: ${current}"
echo "Latest ai-usagebar:  ${latest}"

if [[ "$current" == "$latest" ]]; then
	echo "✅ ai-usagebar is up to date"
	echo "updated=false" >>"$GITHUB_OUTPUT"
	exit 0
fi

nix run nixpkgs#nix-update -- --flake ai-usagebar --version "$latest" --build

echo "✅ Updated ${PKG_NIX}"
git diff "$PKG_NIX"

{
	echo "updated=true"
	echo "version=${latest}"
	echo "files=${PKG_NIX}"
} >>"$GITHUB_OUTPUT"
