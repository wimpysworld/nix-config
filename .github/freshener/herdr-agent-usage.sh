#!/usr/bin/env bash
# Update herdr-agent-usage from the latest stable Go module release.
set -euo pipefail

PKG_NIX="pkgs/herdr-agent-usage/default.nix"

current=$(awk '/^  version = "/ { match($0, /version = "([^"]+)"/, arr); print arr[1]; exit }' "$PKG_NIX")
latest=$(curl -fsSL "https://proxy.golang.org/github.com/senna-lang/herdr-agent-usage/@latest" | jq -r '.Version' | sed 's/^v//')

if [[ -z "$current" ]]; then
  echo "❌ Could not determine current herdr-agent-usage version"
  exit 1
fi
if [[ -z "$latest" || "$latest" == "null" ]]; then
  echo "❌ Could not determine latest herdr-agent-usage version"
  exit 1
fi

echo "Current herdr-agent-usage: ${current}"
echo "Latest herdr-agent-usage:  ${latest}"

if [[ "$current" == "$latest" ]]; then
  echo "✅ herdr-agent-usage is up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

echo "⬆️  Updating to ${latest}"
nix run nixpkgs#nix-update -- --flake herdr-agent-usage --version "$latest" --build

echo "✅ Updated ${PKG_NIX}"
git diff "$PKG_NIX"

{
  echo "updated=true"
  echo "version=${latest}"
  echo "files=${PKG_NIX}"
} >> "$GITHUB_OUTPUT"
