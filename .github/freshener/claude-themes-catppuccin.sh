#!/usr/bin/env bash
# Update the Catppuccin Claude Code plugin from its newest path-specific commit.
set -euo pipefail

PKG_NIX="pkgs/claude-themes-catppuccin/default.nix"
REPOSITORY="matcra587/claude-themes"
PLUGIN_PATH="plugins/catppuccin"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

current_rev=$(sed -n 's/^    rev = "\([0-9a-f]\{40\}\)";/\1/p' "$PKG_NIX")
current_version=$(sed -n 's/^  version = "\([^"]*\)";/\1/p' "$PKG_NIX")
metadata=$(curl -fsSL "https://api.github.com/repos/${REPOSITORY}/commits?path=plugins%2Fcatppuccin&per_page=1")
latest_rev=$(jq -r '.[0].sha' <<< "$metadata")

if [[ ! "$current_rev" =~ ^[0-9a-f]{40}$ ]]; then
  echo "❌ Could not determine the current Catppuccin plugin revision"
  exit 1
fi
if [[ ! "$latest_rev" =~ ^[0-9a-f]{40}$ ]]; then
  echo "❌ Could not determine the latest Catppuccin plugin revision"
  exit 1
fi
if [[ ! "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
  echo "❌ Could not determine the current Catppuccin plugin version"
  exit 1
fi

plugin_manifest=$(curl -fsSL "https://raw.githubusercontent.com/${REPOSITORY}/${latest_rev}/${PLUGIN_PATH}/.claude-plugin/plugin.json")
if ! latest_version=$(jq -er '
  if type == "object"
    and (.version | type == "string")
    and (.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?(\\+[0-9A-Za-z.-]+)?$"))
  then .version
  else error("missing or malformed plugin version")
  end
' <<< "$plugin_manifest"); then
  echo "❌ Could not determine a valid Catppuccin plugin version"
  exit 1
fi

echo "Current Catppuccin plugin: ${current_rev}"
echo "Latest Catppuccin plugin:  ${latest_rev}"
echo "Current Catppuccin version: ${current_version}"
echo "Latest Catppuccin version:  ${latest_version}"

if [[ "$current_rev" == "$latest_rev" && "$current_version" == "$latest_version" ]]; then
  echo "✅ The Catppuccin plugin is up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

package_backup=$(mktemp "${PKG_NIX}.backup.XXXXXX")
package_candidate=""
build_log=$(mktemp)
backup_ready=false
restore_package=true
cleanup() {
  status=$?
  trap - EXIT
  set +e
  if [[ "$backup_ready" == true && "$restore_package" == true ]]; then
    mv -- "$package_backup" "$PKG_NIX"
  else
    rm -f -- "$package_backup"
  fi
  if [[ -n "$package_candidate" ]]; then
    rm -f -- "$package_candidate"
  fi
  rm -f -- "$build_log"
  exit "$status"
}
trap cleanup EXIT
cp -p -- "$PKG_NIX" "$package_backup"
backup_ready=true

update_package() {
  local version=$1
  local rev=$2
  local hash=$3

  package_candidate=$(mktemp "${PKG_NIX}.update.XXXXXX")
  cp -- "$PKG_NIX" "$package_candidate"
  sed -i \
    -e "s|^  version = \".*\";|  version = \"${version}\";|" \
    -e "s|^    rev = \".*\";|    rev = \"${rev}\";|" \
    -e "s|^    hash = \".*\";|    hash = \"${hash}\";|" \
    "$package_candidate"

  if [[ $(sed -n 's/^  version = "\([^"]*\)";/\1/p' "$package_candidate") != "$version" \
    || $(sed -n 's/^    rev = "\([^"]*\)";/\1/p' "$package_candidate") != "$rev" \
    || $(sed -n 's/^    hash = "\([^"]*\)";/\1/p' "$package_candidate") != "$hash" ]]; then
    echo "❌ Could not update all Catppuccin package fields"
    return 1
  fi

  mv -- "$package_candidate" "$PKG_NIX"
  package_candidate=""
}

update_package "$latest_version" "$latest_rev" "$FAKE_HASH"

if nix build .#claude-themes-catppuccin --no-link -L > "$build_log" 2>&1; then
  echo "❌ The Catppuccin plugin unexpectedly built with the fake source hash"
  exit 1
fi
source_hash=$(sed -n 's/^[[:space:]]*got:[[:space:]]*\(sha256-[A-Za-z0-9+/=]*\)$/\1/p' "$build_log" | tail -n 1)
if [[ ! "$source_hash" =~ ^sha256-[A-Za-z0-9+/=]+$ ]]; then
  echo "❌ Could not determine the Catppuccin plugin source hash"
  tail -n 40 "$build_log"
  exit 1
fi

update_package "$latest_version" "$latest_rev" "$source_hash"
nix fmt "$PKG_NIX"
nix build .#claude-themes-catppuccin --no-link -L
restore_package=false

echo "✅ Updated ${PLUGIN_PATH} to ${latest_rev}"
git diff "$PKG_NIX"

{
  echo "updated=true"
  echo "version=${latest_version}"
  echo "files=${PKG_NIX}"
} >> "$GITHUB_OUTPUT"
