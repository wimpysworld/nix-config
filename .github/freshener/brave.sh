#!/usr/bin/env bash
# Update Brave only after all stable platforms and checksums pass validation.
set -euo pipefail

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must name an output file}"
PKG_NIX="pkgs/brave/release.nix"
REPOSITORY="https://github.com/brave/brave-browser"

current=$(sed -n 's/^  version = "\([^"]*\)";$/\1/p' "$PKG_NIX")
if [[ ! "$current" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid current Brave version" >&2
  exit 1
fi

latest=""
for platform in linux-arm64 linux-x64 macos-arm64; do
  version=$(curl -fsSL "https://versions.brave.com/latest/release-${platform}.version" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || (-n "$latest" && "$version" != "$latest") ]]; then
    echo "Invalid or inconsistent stable Brave version for ${platform}" >&2
    exit 1
  fi
  latest="$version"
done

release=$(curl -fsSL "https://api.github.com/repos/brave/brave-browser/releases/tags/v${latest}")
jq -e --arg tag "v${latest}" 'select(.draft == false and .prerelease == false and .tag_name == $tag)' <<< "$release" > /dev/null

declare -A archives=(
  [aarch64-linux]="brave-browser_${latest}_arm64.deb"
  [x86_64-linux]="brave-browser_${latest}_amd64.deb"
  [aarch64-darwin]="Brave-Browser-arm64.dmg"
)
declare -A hashes
for platform in aarch64-linux x86_64-linux aarch64-darwin; do
  archive="${archives[$platform]}"
  jq -e --arg name "$archive" '
    .assets as $assets |
    all([$name, ($name + ".sha256")][]; . as $asset |
      any($assets[]; .name == $asset and .state == "uploaded"))
  ' <<< "$release" > /dev/null
  checksum=$(curl -fsSL "${REPOSITORY}/releases/download/v${latest}/${archive}.sha256")
  if [[ ! "$checksum" =~ ^([[:xdigit:]]{64})[[:blank:]]+\*?([^[:space:]]+)[[:space:]]*$ || "${BASH_REMATCH[2]}" != "$archive" ]]; then
    echo "Invalid SHA-256 checksum for ${archive}" >&2
    exit 1
  fi
  hashes[$platform]=$(nix hash convert --hash-algo sha256 --to sri "${BASH_REMATCH[1]}")
  if [[ ! "${hashes[$platform]}" =~ ^sha256-[A-Za-z0-9+/]{43}=$ ]]; then
    echo "Invalid SRI hash for ${archive}" >&2
    exit 1
  fi
done

# Generate one file after every remote input passes, then replace it atomically.
tmp=$(mktemp "${PKG_NIX}.XXXXXX")
trap 'rm -f "$tmp"' EXIT
cat > "$tmp" <<EOF
# Updated by .github/freshener/brave.sh.
rec {
  pname = "brave";
  version = "${latest}";

  archives = {
    aarch64-linux = {
      url = "${REPOSITORY}/releases/download/v\${version}/brave-browser_\${version}_arm64.deb";
      hash = "${hashes[aarch64-linux]}";
    };
    x86_64-linux = {
      url = "${REPOSITORY}/releases/download/v\${version}/brave-browser_\${version}_amd64.deb";
      hash = "${hashes[x86_64-linux]}";
    };
    aarch64-darwin = {
      url = "${REPOSITORY}/releases/download/v\${version}/Brave-Browser-arm64.dmg";
      hash = "${hashes[aarch64-darwin]}";
    };
  };
}
EOF

if cmp -s "$PKG_NIX" "$tmp"; then
  echo "Brave ${current} is up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

chmod --reference="$PKG_NIX" "$tmp"
echo "Updating Brave ${current} to ${latest}"
{
  echo "updated=true"
  echo "version=${latest}"
  echo "files=${PKG_NIX}"
} >> "$GITHUB_OUTPUT"
mv "$tmp" "$PKG_NIX"
