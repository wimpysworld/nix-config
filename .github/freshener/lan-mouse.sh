#!/usr/bin/env bash
# Update the Lan Mouse flake input to the latest stable release tag.
set -euo pipefail

current=$(awk -F/ '/lan-mouse.url = "github:feschber\/lan-mouse\// { sub(/";$/, "", $NF); print $NF }' flake.nix)
latest=$(curl -fsSL "https://api.github.com/repos/feschber/lan-mouse/tags?per_page=100" \
  | jq -r '.[].name' \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -V \
  | tail -n 1)

if [[ -z "$current" ]]; then
  echo "❌ Could not determine the current Lan Mouse release"
  exit 1
fi
if [[ -z "$latest" ]]; then
  echo "❌ Could not determine the latest Lan Mouse release"
  exit 1
fi

echo "Current Lan Mouse: ${current}"
echo "Latest Lan Mouse:  ${latest}"

if [[ "$current" == "$latest" ]]; then
  echo "✅ Lan Mouse is up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

perl -0pi -e 's#lan-mouse\.url = "github:feschber/lan-mouse/[^"]+";#lan-mouse.url = "github:feschber/lan-mouse/'"$latest"'";#' flake.nix
nix flake update lan-mouse
nix fmt flake.nix

git diff flake.nix flake.lock

{
  echo "updated=true"
  echo "version=${latest}"
  echo "files=flake.nix flake.lock"
} >> "$GITHUB_OUTPUT"
