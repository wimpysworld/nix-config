#!/usr/bin/env bash
# Update herdr-web-ui from the latest stable GitHub release. Upstream also
# publishes `remote-vN` releases for its bridge bundle, so only `vX.Y.Z` tags
# count.
set -euo pipefail

PKG_NIX="pkgs/herdr-web-ui/default.nix"

current=$(awk '/^  version = "/ { sub(/^  version = "/, ""); sub(/".*/, ""); print; exit }' "$PKG_NIX")
latest=$(curl -fsSL "https://api.github.com/repos/devswha/herdr-web-ui/releases?per_page=30" |
	jq -r '[.[] | select(.draft == false and .prerelease == false and (.tag_name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")))][0].tag_name' |
	sed 's/^v//')

if [[ -z "$current" ]]; then
	echo "❌ Could not determine current herdr-web-ui version"
	exit 1
fi
if [[ -z "$latest" || "$latest" == "null" ]]; then
	echo "❌ Could not determine latest herdr-web-ui version"
	exit 1
fi

echo "Current herdr-web-ui: ${current}"
echo "Latest herdr-web-ui:  ${latest}"

if [[ "$current" == "$latest" ]]; then
	echo "✅ herdr-web-ui is up to date"
	echo "updated=false" >>"$GITHUB_OUTPUT"
	exit 0
fi

# The `node_modules` fixed-output derivation has its own hash.
nix run nixpkgs#nix-update -- --flake herdr-web-ui --version "$latest" --subpackage node_modules --build

echo "✅ Updated ${PKG_NIX}"
git diff "$PKG_NIX"

{
	echo "updated=true"
	echo "version=${latest}"
	echo "files=${PKG_NIX}"
} >>"$GITHUB_OUTPUT"
