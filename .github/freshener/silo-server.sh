#!/usr/bin/env bash
# Update silo-server from the newest commit on its default branch.
#
# Upstream publishes no tags or releases, so nix-update follows the branch and
# writes a `0-unstable-<date>` version with the new revision and hashes.
set -euo pipefail

PKG_NIX="pkgs/silo-server/default.nix"
REPOSITORY="Silo-Server/silo-server"

current_rev=$(sed -n 's/^    rev = "\([0-9a-f]\{40\}\)";/\1/p' "$PKG_NIX")
latest_rev=$(curl -fsSL "https://api.github.com/repos/${REPOSITORY}/commits?per_page=1" | jq -r '.[0].sha')

if [[ ! "$current_rev" =~ ^[0-9a-f]{40}$ ]]; then
	echo "❌ Could not determine current silo-server revision"
	exit 1
fi
if [[ ! "$latest_rev" =~ ^[0-9a-f]{40}$ ]]; then
	echo "❌ Could not determine latest silo-server revision"
	exit 1
fi

echo "Current silo-server: ${current_rev}"
echo "Latest silo-server:  ${latest_rev}"

if [[ "$current_rev" == "$latest_rev" ]]; then
	echo "✅ silo-server is up to date"
	echo "updated=false" >>"$GITHUB_OUTPUT"
	exit 0
fi

# The `web.pnpmDeps` fixed-output derivation has its own hash alongside vendorHash.
nix run nixpkgs#nix-update -- --flake silo-server --version=branch --subpackage web.pnpmDeps --build

latest=$(sed -n 's/^  version = "\([^"]*\)";/\1/p' "$PKG_NIX")
echo "✅ Updated ${PKG_NIX}"
git diff "$PKG_NIX"

{
	echo "updated=true"
	echo "version=${latest}"
	echo "files=${PKG_NIX}"
} >>"$GITHUB_OUTPUT"
