#!/usr/bin/env bash
# Update herdr-agent-quota from the latest stable GitHub release.
set -euo pipefail

PKG_NIX="pkgs/herdr-agent-quota/default.nix"

current=$(awk '/^  version = "/ { match($0, /version = "([^"]+)"/, arr); print arr[1]; exit }' "$PKG_NIX")
latest=$(curl -fsSL "https://api.github.com/repos/levi-qiao/herdr-agent-quota/releases/latest" |
	jq -r '.tag_name' |
	sed 's/^v//')

if [[ -z "$current" ]]; then
	echo "❌ Could not determine current herdr-agent-quota version"
	exit 1
fi
if [[ -z "$latest" || "$latest" == "null" ]]; then
	echo "❌ Could not determine latest herdr-agent-quota version"
	exit 1
fi

echo "Current herdr-agent-quota: ${current}"
echo "Latest herdr-agent-quota:  ${latest}"

if [[ "$current" == "$latest" ]]; then
	echo "✅ herdr-agent-quota is up to date"
	echo "updated=false" >>"$GITHUB_OUTPUT"
	exit 0
fi

nix run nixpkgs#nix-update -- --flake herdr-agent-quota --version "$latest" --build

echo "✅ Updated ${PKG_NIX}"
git diff "$PKG_NIX"

{
	echo "updated=true"
	echo "version=${latest}"
	echo "files=${PKG_NIX}"
} >>"$GITHUB_OUTPUT"
