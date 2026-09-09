#!/usr/bin/env bash
# Update Weave from the latest stable GitHub release.
set -euo pipefail

PKG_NIX="pkgs/weave/default.nix"

current=$(awk '/^  version = "/ { match($0, /version = "([^"]+)"/, arr); print arr[1]; exit }' "$PKG_NIX")
latest=$(curl -fsSL "https://api.github.com/repos/matze/weave/releases/latest" \
  | jq -r 'select(.draft == false and .prerelease == false) | .tag_name // empty' \
  | sed 's/^v//')

if [[ -z "$current" ]]; then
  echo "❌ Could not determine current Weave version"
  exit 1
fi
if [[ -z "$latest" ]]; then
  echo "❌ Could not determine latest stable Weave version"
  exit 1
fi

echo "Current Weave: ${current}"
echo "Latest Weave:  ${latest}"

if [[ "$current" == "$latest" ]]; then
  echo "✅ Weave is up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

echo "⬆️  Updating to ${latest}"
nix run nixpkgs#nix-update -- --flake weave --version "$latest" --build

echo "✅ Updated ${PKG_NIX}"
git diff "$PKG_NIX"

{
  echo "updated=true"
  echo "version=${latest}"
  echo "files=${PKG_NIX}"
} >> "$GITHUB_OUTPUT"
