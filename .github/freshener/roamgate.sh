#!/usr/bin/env bash
# Update roamgate from the latest stable GitHub release. Only `vX.Y.Z` tags
# count.
set -euo pipefail

PKG_NIX="pkgs/roamgate/default.nix"

current=$(awk '/^  version = "/ { sub(/^  version = "/, ""); sub(/".*/, ""); print; exit }' "$PKG_NIX")
latest=$(curl -fsSL "https://api.github.com/repos/powerfooI/roamgate/releases?per_page=30" |
	jq -r '[.[] | select(.draft == false and .prerelease == false and (.tag_name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")))][0].tag_name' |
	sed 's/^v//')

if [[ -z "$current" ]]; then
	echo "❌ Could not determine current roamgate version"
	exit 1
fi
if [[ -z "$latest" || "$latest" == "null" ]]; then
	echo "❌ Could not determine latest roamgate version"
	exit 1
fi

echo "Current roamgate: ${current}"
echo "Latest roamgate:  ${latest}"

if [[ "$current" == "$latest" ]]; then
	echo "✅ roamgate is up to date"
	echo "updated=false" >>"$GITHUB_OUTPUT"
	exit 0
fi

# The `node_modules` fixed-output derivation has its own hash.
nix run nixpkgs#nix-update -- --flake roamgate --version "$latest" --subpackage node_modules --build

echo "✅ Updated ${PKG_NIX}"
git diff "$PKG_NIX"

{
	echo "updated=true"
	echo "version=${latest}"
	echo "files=${PKG_NIX}"
} >>"$GITHUB_OUTPUT"
