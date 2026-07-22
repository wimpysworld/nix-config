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

overlay=overlays/default.nix
fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
build_log=$(mktemp)
trap 'rm -f "$build_log"' EXIT

# Force Nix to report the npm dependency hash produced by this repository's
# locked Paseo and nixpkgs inputs.
perl -0pi -e 's#The v[0-9]+\.[0-9]+\.[0-9]+ tag ships#The '"$latest"' tag ships#' "$overlay"
perl -0pi -e 's#npmDepsHash = "sha256-[A-Za-z0-9+/=]+";#npmDepsHash = "'"$fake_hash"'";#' "$overlay"

if nix build .#paseo --no-link -L >"$build_log" 2>&1; then
  echo "❌ Paseo unexpectedly built with the fake npm dependency hash"
  exit 1
fi

npm_deps_hash=$(sed -n 's/^[[:space:]]*got:[[:space:]]*\(sha256-[A-Za-z0-9+/=]*\)$/\1/p' "$build_log" | tail -n 1)
if [[ ! "$npm_deps_hash" =~ ^sha256-[A-Za-z0-9+/=]+$ ]]; then
  echo "❌ Could not determine the Paseo npm dependency hash"
  tail -n 40 "$build_log"
  exit 1
fi

echo "Paseo npm dependencies: ${npm_deps_hash}"
perl -0pi -e 's#npmDepsHash = "sha256-[A-Za-z0-9+/=]+";#npmDepsHash = "'"$npm_deps_hash"'";#' "$overlay"

nix fmt flake.nix "$overlay"
nix build .#paseo .#paseo-desktop --no-link -L

git diff flake.nix flake.lock "$overlay"

{
  echo "updated=true"
  echo "version=${latest}"
  echo "files=flake.nix flake.lock ${overlay}"
} >> "$GITHUB_OUTPUT"
