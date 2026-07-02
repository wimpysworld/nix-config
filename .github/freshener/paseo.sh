#!/usr/bin/env bash
# Update the Paseo flake input to the latest stable release tag.
#
# The input pins a semver tag inside its URL. Upstream publishes prereleases
# with suffixes such as -rc.1 and -beta.2, so the strict pattern below keeps to
# stable releases only.
set -euo pipefail

current=$(awk -F/ '/paseo.url = "github:getpaseo\/paseo\// { sub(/";$/, "", $NF); print $NF }' flake.nix)
latest=$(curl -fsSL "https://api.github.com/repos/getpaseo/paseo/tags?per_page=100" \
  | jq -r '.[].name' \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -V \
  | tail -n 1)

if [[ -z "$current" ]]; then
  echo "❌ Could not determine current Paseo release"
  exit 1
fi
if [[ -z "$latest" ]]; then
  echo "❌ Could not determine latest Paseo release"
  exit 1
fi

echo "Current Paseo: ${current}"
echo "Latest Paseo:  ${latest}"

if [[ "$current" == "$latest" ]]; then
  echo "✅ Paseo is up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

perl -0pi -e 's#paseo\.url = "github:getpaseo/paseo/[^"]+";#paseo.url = "github:getpaseo/paseo/'"$latest"'";#' flake.nix
nix flake update paseo
nix fmt flake.nix

git diff flake.nix flake.lock

{
  echo "updated=true"
  echo "version=${latest}"
  echo "files=flake.nix flake.lock"
} >> "$GITHUB_OUTPUT"
