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

# Keep the managed config's schema stamp in lockstep with the new release. The
# helper writes updated=true plus version/files outputs when it stamps a new
# version, and those files join the flake bump in the same pull request. A
# helper failure aborts the freshener: publishing a flake bump without its
# schema stamp would leave `hermes doctor` reporting the config as outdated.
SCHEMA_VERSION="$latest"
SCHEMA_FILES=""
.github/freshener/hermes-schema.sh
SCHEMA_FILES=$(sed -n 's/^files=//p' "$GITHUB_OUTPUT")
if [[ -n "$SCHEMA_FILES" ]]; then
  SCHEMA_VERSION=$(sed -n 's/^version=//p' "$GITHUB_OUTPUT")
fi

{
  echo "updated=true"
  echo "version=${latest} (config schema v${SCHEMA_VERSION})"
  echo "files=flake.nix flake.lock${SCHEMA_FILES:+ ${SCHEMA_FILES}}"
} >> "$GITHUB_OUTPUT"
