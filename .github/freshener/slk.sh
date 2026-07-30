#!/usr/bin/env bash
# Update the slk package from the Go module proxy.
#
# The proxy is the version source rather than the GitHub releases API, because
# it needs no token and has no practical rate limit. Its @latest endpoint
# prefers stable releases, so the prerelease tags goreleaser publishes are
# skipped. slk builds from the Git tag, not from release assets, so a tag is
# enough for the update to succeed.
#
# The derivation is a plain buildGoModule with one src and one vendorHash, so
# nix-update can rewrite both instead of hand-rolled prefetch and sed.
set -euo pipefail

PKG_NIX="pkgs/slk/default.nix"

current=$(awk '/^  version = "/ { match($0, /version = "([^"]+)"/, arr); print arr[1]; exit }' "$PKG_NIX")
latest=$(curl -fsSL "https://proxy.golang.org/github.com/gammons/slk/@latest" | jq -r '.Version' | sed 's/^v//')

if [[ -z "$current" ]]; then
  echo "❌ Could not determine current slk version"
  exit 1
fi
if [[ -z "$latest" || "$latest" == "null" ]]; then
  echo "❌ Could not determine latest slk version"
  exit 1
fi

echo "Current slk: ${current}"
echo "Latest slk:  ${latest}"

if [[ "$current" == "$latest" ]]; then
  echo "✅ slk is up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

# nix-update rewrites the version, the source hash, and the vendor hash. The
# --build flag makes it compile the result, so a broken update fails here
# rather than in the pull request.
echo "⬆️  Updating to ${latest}"
nix run nixpkgs#nix-update -- --flake slk --version "$latest" --build

echo "✅ Updated ${PKG_NIX}"
git diff "$PKG_NIX"

{
  echo "updated=true"
  echo "version=${latest}"
  echo "files=${PKG_NIX}"
} >> "$GITHUB_OUTPUT"
