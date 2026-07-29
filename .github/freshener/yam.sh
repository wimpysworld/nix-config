#!/usr/bin/env bash
# Update the yam package from the Go module proxy.
#
# Chainguard publish no GitHub releases for yam, only Git tags, so the Go
# module proxy is the version source. It needs no token and has no practical
# rate limit.
#
# The derivation is a plain buildGoModule with one src and one vendorHash, so
# nix-update can rewrite both instead of hand-rolled prefetch and sed.
set -euo pipefail

PKG_NIX="pkgs/yam/default.nix"

current=$(awk '/^  version = "/ { match($0, /version = "([^"]+)"/, arr); print arr[1]; exit }' "$PKG_NIX")
latest=$(curl -fsSL "https://proxy.golang.org/github.com/chainguard-dev/yam/@latest" | jq -r '.Version' | sed 's/^v//')

if [[ -z "$current" ]]; then
  echo "❌ Could not determine current yam version"
  exit 1
fi
if [[ -z "$latest" || "$latest" == "null" ]]; then
  echo "❌ Could not determine latest yam version"
  exit 1
fi

echo "Current yam: ${current}"
echo "Latest yam:  ${latest}"

if [[ "$current" == "$latest" ]]; then
  echo "✅ yam is up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

# nix-update rewrites the version, the source hash, and the vendor hash. The
# --build flag makes it compile the result, so a broken update fails here
# rather than in the pull request.
echo "⬆️  Updating to ${latest}"
nix run nixpkgs#nix-update -- --flake yam --version "$latest" --build

echo "✅ Updated ${PKG_NIX}"
git diff "$PKG_NIX"

{
  echo "updated=true"
  echo "version=${latest}"
  echo "files=${PKG_NIX}"
} >> "$GITHUB_OUTPUT"
