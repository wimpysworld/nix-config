#!/usr/bin/env bash
# Update the Voxtype flake input, which pins a tag inside its URL.
set -euo pipefail

current=$(awk -F/ '/voxtype.url = "github:peteonrails\/voxtype\// { sub(/";$/, "", $NF); print $NF }' flake.nix)
latest=$(curl -fsSL "https://api.github.com/repos/peteonrails/voxtype/tags?per_page=100" \
  | jq -r '.[].name' \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -V \
  | tail -n 1)

if [[ -z "$current" ]]; then
  echo "❌ Could not determine current Voxtype release"
  exit 1
fi
if [[ -z "$latest" ]]; then
  echo "❌ Could not determine latest Voxtype release"
  exit 1
fi

echo "Current Voxtype: ${current}"
echo "Latest Voxtype:  ${latest}"

if [[ "$current" == "$latest" ]]; then
  echo "✅ Voxtype is up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

perl -0pi -e 's#voxtype\.url = "github:peteonrails/voxtype/[^"]+";#voxtype.url = "github:peteonrails/voxtype/'"$latest"'";#' flake.nix
nix flake update voxtype
nix fmt flake.nix

git diff flake.nix flake.lock

{
  echo "updated=true"
  echo "version=${latest}"
  echo "files=flake.nix flake.lock"
} >> "$GITHUB_OUTPUT"
