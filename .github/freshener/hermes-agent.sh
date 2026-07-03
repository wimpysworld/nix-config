#!/usr/bin/env bash
# Update the Hermes Agent flake input, which pins a tag inside its tarball URL.
set -euo pipefail

current=$(awk -F/ '/hermes-agent.url = "https:\/\/github.com\/NousResearch\/hermes-agent\// { sub(/\.tar\.gz";$/, "", $NF); print $NF }' flake.nix)
latest=$(curl -fsSL "https://api.github.com/repos/NousResearch/hermes-agent/tags?per_page=100" \
  | jq -r '.[].name' \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -V \
  | tail -n 1)

if [[ -z "$current" ]]; then
  echo "❌ Could not determine current Hermes Agent release"
  exit 1
fi
if [[ -z "$latest" ]]; then
  echo "❌ Could not determine latest Hermes Agent release"
  exit 1
fi

echo "Current Hermes Agent: ${current}"
echo "Latest Hermes Agent:  ${latest}"

if [[ "$current" == "$latest" ]]; then
  echo "✅ Hermes Agent is up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

perl -0pi -e 's#hermes-agent\.url = "https://github\.com/NousResearch/hermes-agent/archive/refs/tags/[^"]+";#hermes-agent.url = "https://github.com/NousResearch/hermes-agent/archive/refs/tags/'"$latest"'.tar.gz";#' flake.nix
nix flake update hermes-agent
nix fmt flake.nix

git diff flake.nix flake.lock

{
  echo "updated=true"
  echo "version=${latest}"
  echo "files=flake.nix flake.lock"
} >> "$GITHUB_OUTPUT"
