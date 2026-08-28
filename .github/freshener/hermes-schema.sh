#!/usr/bin/env bash
# After bumping the Hermes Agent flake input, keep the managed config's schema
# version stamp in lockstep with the new release.
#
# The Hermes mixin stamps `_config_version` into the Nix-generated config.yaml
# (nixos/_mixins/server/hermes/default.nix, `hermesConfigSchemaVersion`). That
# value must match `DEFAULT_CONFIG["_config_version"]` from the pinned Hermes
# release, or `hermes doctor` reports the managed config as outdated.
#
# This script extracts the version from the pinned tarball, compares it to the
# stamp, and when they drift, updates the stamp and exports the extra files to
# stage. It runs after the flake input bump, so the same pull request carries
# both changes and the stamp never lags.
set -euo pipefail

MODULE="nixos/_mixins/server/hermes/default.nix"

current=$(awk '
  /hermesConfigSchemaVersion = / {
    sub(/.*= /, ""); sub(/;.*/, ""); print; exit
  }' "$MODULE")

if [[ -z "$current" ]]; then
  echo "❌ Could not determine hermesConfigSchemaVersion in $MODULE"
  exit 1
fi

# Resolve the pinned Hermes release from flake.nix, then read
# DEFAULT_CONFIG["_config_version"] straight out of the pinned source tree.
pinned=$(awk -F/ '/hermes-agent.url = "https:\/\/github.com\/NousResearch\/hermes-agent\// { sub(/\.tar\.gz";$/, "", $NF); print $NF }' flake.nix)

if [[ -z "$pinned" ]]; then
  echo "❌ Could not determine pinned Hermes Agent release from flake.nix"
  exit 1
fi

latest=$(curl -fsSL "https://github.com/NousResearch/hermes-agent/archive/refs/tags/${pinned}.tar.gz" \
  | tar xzO "hermes-agent-${pinned#v}/hermes_cli/config_defaults.py" \
  | grep -oE '"_config_version": [0-9]+' \
  | grep -oE '[0-9]+')

if [[ -z "$latest" ]]; then
  echo "❌ Could not extract _config_version from Hermes Agent ${pinned}"
  exit 1
fi

echo "Pinned Hermes Agent:        ${pinned}"
echo "Config schema in release:   ${latest}"
echo "hermesConfigSchemaVersion:  ${current}"

if [[ "$current" == "$latest" ]]; then
  echo "✅ Config schema stamp is in lockstep"
  exit 0
fi

perl -0pi -e "s/hermesConfigSchemaVersion = ${current};/hermesConfigSchemaVersion = ${latest};/" "$MODULE"

# Keep the release reference in the adjacent comment accurate.
perl -0pi -e "s/\\(hermes-agent [0-9.]+ \\/ [0-9.]+ carries/\\(hermes-agent HPLACEHOLDER\\/ ${pinned} carries/" "$MODULE"
release_ver=$(curl -fsSL "https://raw.githubusercontent.com/NousResearch/hermes-agent/${pinned}/pyproject.toml" \
  | grep -oE '^version = "[0-9.]+"' \
  | grep -oE '[0-9.]+' || true)
if [[ -n "$release_ver" ]]; then
  perl -0pi -e "s/\\(hermes-agent HPLACEHOLDER\\/ ${pinned} carries/\\(hermes-agent ${release_ver} \\/ ${pinned#v} carries/" "$MODULE"
else
  # Leave a clean value even when pyproject.toml cannot be fetched.
  perl -0pi -e "s/\\(hermes-agent HPLACEHOLDER\\/ ${pinned} carries/\\(hermes-agent ${pinned#v} carries/" "$MODULE"
fi

git diff "$MODULE"

{
  echo "updated=true"
  echo "version=${latest}"
  echo "files=${MODULE}"
} >> "$GITHUB_OUTPUT"
