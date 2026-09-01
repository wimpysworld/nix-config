#!/usr/bin/env bash
# Update the Handy flake input, which pins a tag inside its URL.
set -euo pipefail

current=$(awk -F/ '/handy.url = "github:cjpais\/Handy\// { sub(/";$/, "", $NF); print $NF }' flake.nix)
latest=$(curl -fsSL "https://api.github.com/repos/cjpais/Handy/tags?per_page=100" \
  | jq -r '.[].name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' \
  | sort -V \
  | tail -n 1)

if [[ -z "$current" ]]; then
  echo "❌ Could not determine current Handy release"
  exit 1
fi
if [[ -z "$latest" ]]; then
  echo "❌ Could not determine latest Handy release"
  exit 1
fi

echo "Current Handy: ${current}"
echo "Latest Handy:  ${latest}"

if [[ "$current" == "$latest" ]]; then
  echo "✅ Handy is up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

perl -0pi -e 's#handy\.url = "github:cjpais/Handy/[^"]+";#handy.url = "github:cjpais/Handy/'"$latest"'";#' flake.nix
nix flake update handy
nix fmt flake.nix

git diff flake.nix flake.lock

{
  echo "updated=true"
  echo "version=${latest}"
  echo "files=flake.nix flake.lock"
} >> "$GITHUB_OUTPUT"
