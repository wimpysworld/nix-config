#!/usr/bin/env bash
# Update Manuscript from the latest stable GitLab tag.
set -euo pipefail

PKG_NIX="pkgs/manuscript/default.nix"

current=$(awk '/^  version = "/ { match($0, /version = "([^"]+)"/, arr); print arr[1]; exit }' "$PKG_NIX")
latest=$(git ls-remote --tags --refs https://gitlab.com/ilshat-apps/manuscript.git \
  | awk '$2 ~ /^refs\/tags\/v[0-9]+\.[0-9]+\.[0-9]+$/ { sub(/^refs\/tags\/v/, "", $2); print $2 }' \
  | sort -V \
  | tail -n 1)

if [[ -z "$current" ]]; then
  echo "❌ Could not determine current Manuscript version"
  exit 1
fi
if [[ -z "$latest" ]]; then
  echo "❌ Could not determine latest stable Manuscript version"
  exit 1
fi

echo "Current Manuscript: ${current}"
echo "Latest Manuscript:  ${latest}"

if [[ "$current" == "$latest" ]]; then
  echo "✅ Manuscript is up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

echo "⬆️  Updating to ${latest}"
nix run nixpkgs#nix-update -- --flake manuscript --version "$latest" --build

echo "✅ Updated ${PKG_NIX}"
git diff "$PKG_NIX"

{
  echo "updated=true"
  echo "version=${latest}"
  echo "files=${PKG_NIX}"
} >> "$GITHUB_OUTPUT"
