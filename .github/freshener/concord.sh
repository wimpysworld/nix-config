#!/usr/bin/env bash
# Update the Concord flake input, which pins a tag inside its URL.
set -euo pipefail

current=$(awk -F/ '/concord.url = "github:chojs23\/concord\// { sub(/";$/, "", $NF); print $NF }' flake.nix)
latest=$(curl -fsSL "https://api.github.com/repos/chojs23/concord/tags?per_page=100" \
  | jq -r '.[].name' \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -V \
  | tail -n 1)

if [[ -z "$current" ]]; then
  echo "❌ Could not determine current Concord release"
  exit 1
fi
if [[ -z "$latest" ]]; then
  echo "❌ Could not determine latest Concord release"
  exit 1
fi

echo "Current Concord: ${current}"
echo "Latest Concord:  ${latest}"

if [[ "$current" == "$latest" ]]; then
  echo "✅ Concord is up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

perl -0pi -e 's#concord\.url = "github:chojs23/concord/[^"]+";#concord.url = "github:chojs23/concord/'"$latest"'";#' flake.nix
nix flake update concord
nix fmt flake.nix

git diff flake.nix flake.lock

{
  echo "updated=true"
  echo "version=${latest}"
  echo "files=flake.nix flake.lock"
} >> "$GITHUB_OUTPUT"
