#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq git nix-prefetch-git common-updater-scripts gnused nix-update

set -euo pipefail

OWNER="wez"
REPO="wezterm"

NIX_CONFIG_ROOT=$(git rev-parse --show-toplevel)
PACKAGE_NIX_ATTR_PATH="wezterm"

# For wezterm, the version is 0-unstable-YYYY-MM-DD, so use the latest
# commit date and SHA rather than a release tag.
LATEST_COMMIT_INFO=$(curl ${GITHUB_TOKEN:+--user ":$GITHUB_TOKEN"} --location --silent "https://api.github.com/repos/$OWNER/$REPO/commits/HEAD")
LATEST_REV=$(echo "$LATEST_COMMIT_INFO" | jq --raw-output '.sha')
COMMIT_DATE=$(echo "$LATEST_COMMIT_INFO" | jq --raw-output '.commit.author.date' | cut -d 'T' -f 1)

NEW_VERSION="0-unstable-$COMMIT_DATE"

FETCH_JSON=$(nix-prefetch-git --url "https://github.com/$OWNER/$REPO" --rev "$LATEST_REV" --fetch-submodules)
FETCH_HASH=$(echo "$FETCH_JSON" | jq --raw-output .hash)

(cd "$NIX_CONFIG_ROOT" && update-source-version "$PACKAGE_NIX_ATTR_PATH" "$NEW_VERSION" "$FETCH_HASH" --rev="$LATEST_REV" --ignore-same-version --print-changes)
(cd "$NIX_CONFIG_ROOT" && nix-update --version=skip "$PACKAGE_NIX_ATTR_PATH")

sed -i -e "s#version = \".*\"#version = \"$NEW_VERSION\"#" "$NIX_CONFIG_ROOT/pkgs/wezterm/default.nix"

echo "Wezterm update script finished."
