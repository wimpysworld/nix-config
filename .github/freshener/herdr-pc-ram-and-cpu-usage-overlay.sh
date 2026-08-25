#!/usr/bin/env bash
# Update the Herdr PC RAM and CPU usage overlay from its main branch.
set -euo pipefail

PKG_NIX="pkgs/herdr-pc-ram-and-cpu-usage-overlay/default.nix"
REPOSITORY="ezcorp-org/herdr-pc-ram-and-cpu-usage-overlay"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

current_rev=$(sed -n 's/^    rev = "\([0-9a-f]\{40\}\)";/\1/p' "$PKG_NIX")
metadata=$(curl -fsSL "https://api.github.com/repos/${REPOSITORY}/commits/main")
latest_rev=$(jq -r '.sha' <<< "$metadata")
latest_date=$(jq -r '.commit.committer.date | split("T")[0]' <<< "$metadata")

if [[ ! "$current_rev" =~ ^[0-9a-f]{40}$ ]]; then
  echo "❌ Could not determine the current Herdr overlay revision"
  exit 1
fi
if [[ ! "$latest_rev" =~ ^[0-9a-f]{40}$ || ! "$latest_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "❌ Could not determine the latest Herdr overlay revision"
  exit 1
fi

echo "Current Herdr overlay: ${current_rev}"
echo "Latest Herdr overlay:  ${latest_rev}"

if [[ "$current_rev" == "$latest_rev" ]]; then
  echo "✅ Herdr PC RAM and CPU usage overlay is up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

manifest=$(curl -fsSL "https://raw.githubusercontent.com/${REPOSITORY}/${latest_rev}/Cargo.toml")
manifest_version=$(sed -n 's/^version = "\([^"]*\)"$/\1/p' <<< "$manifest" | head -n 1)
if [[ ! "$manifest_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Could not determine the Herdr overlay manifest version"
  exit 1
fi
latest_version="${manifest_version}-unstable-${latest_date}"

source_url="https://github.com/${REPOSITORY}/archive/${latest_rev}.tar.gz"
source_hash=$(nix store prefetch-file --json --unpack "$source_url" | jq -r '.hash')
if [[ ! "$source_hash" =~ ^sha256-[A-Za-z0-9+/=]+$ ]]; then
  echo "❌ Could not determine the Herdr overlay source hash"
  exit 1
fi

package_backup=$(mktemp)
build_log=""
backup_ready=false
restore_package=true
cleanup() {
  status=$?
  trap - EXIT
  set +e
  if [[ "$backup_ready" == true && "$restore_package" == true ]]; then
    cp -- "$package_backup" "$PKG_NIX"
  fi
  rm -f -- "$package_backup"
  if [[ -n "$build_log" ]]; then
    rm -f -- "$build_log"
  fi
  exit "$status"
}
trap cleanup EXIT
cp -- "$PKG_NIX" "$package_backup"
backup_ready=true

sed -i "s|^  version = \".*\";|  version = \"${latest_version}\";|" "$PKG_NIX"
sed -i "s|^    rev = \".*\";|    rev = \"${latest_rev}\";|" "$PKG_NIX"
sed -i "s|^    hash = \".*\";|    hash = \"${source_hash}\";|" "$PKG_NIX"
sed -i "s|^  cargoHash = \".*\";|  cargoHash = \"${FAKE_HASH}\";|" "$PKG_NIX"

build_log=$(mktemp)
if nix build .#herdr-pc-ram-and-cpu-usage-overlay --no-link -L > "$build_log" 2>&1; then
  echo "❌ Herdr overlay unexpectedly built with the fake Cargo hash"
  exit 1
fi
cargo_hash=$(sed -n 's/^[[:space:]]*got:[[:space:]]*\(sha256-[A-Za-z0-9+/=]*\)$/\1/p' "$build_log" | tail -n 1)
if [[ ! "$cargo_hash" =~ ^sha256-[A-Za-z0-9+/=]+$ ]]; then
  echo "❌ Could not determine the Herdr overlay Cargo hash"
  tail -n 40 "$build_log"
  exit 1
fi
sed -i "s|^  cargoHash = \".*\";|  cargoHash = \"${cargo_hash}\";|" "$PKG_NIX"

nix fmt "$PKG_NIX"
nix build .#herdr-pc-ram-and-cpu-usage-overlay --no-link -L
restore_package=false

echo "✅ Updated ${PKG_NIX}"
git diff "$PKG_NIX"

{
  echo "updated=true"
  echo "version=${latest_version}-${latest_rev:0:8}"
  echo "files=${PKG_NIX}"
} >> "$GITHUB_OUTPUT"
