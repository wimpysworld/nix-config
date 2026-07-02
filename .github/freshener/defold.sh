#!/usr/bin/env bash
# Update the three Defold packages from the latest stable GitHub release.
#
# Move 2 note: nix-update could drive defold, defold-bob, and defold-gdc as
# three calls, but Defold re-pushes artefacts under the same tag, so this script
# compares hashes as well as versions to catch a silent re-push. Keep that
# behaviour if migrating.
set -euo pipefail

DEFOLD_NIX="pkgs/defold/default.nix"
BOB_NIX="pkgs/defold-bob/default.nix"
GDC_NIX="pkgs/defold-gdc/default.nix"

current_defold_version=$(sed -n 's/^  version = "\(.*\)";/\1/p' "$DEFOLD_NIX")
current_bob_version=$(sed -n 's/^  version = "\(.*\)";/\1/p' "$BOB_NIX")
current_gdc_version=$(sed -n 's/^  version = "\(.*\)";/\1/p' "$GDC_NIX")

current_defold_hash=$(sed -n 's/.*hash = "\(sha256-[^"]*\)".*/\1/p' "$DEFOLD_NIX")
current_bob_hash=$(sed -n 's/.*hash = "\(sha256-[^"]*\)".*/\1/p' "$BOB_NIX")
current_gdc_hash=$(sed -n 's/.*hash = "\(sha256-[^"]*\)".*/\1/p' "$GDC_NIX")

echo "Current defold:     ${current_defold_version} ${current_defold_hash}"
echo "Current defold-bob: ${current_bob_version} ${current_bob_hash}"
echo "Current defold-gdc: ${current_gdc_version} ${current_gdc_hash}"

latest=$(curl -fsSL "https://api.github.com/repos/defold/defold/releases?per_page=20" \
  | jq -r '[.[] | select(.prerelease == false)][0].tag_name')

if [[ -z "$latest" || "$latest" == "null" ]]; then
  echo "❌ Could not determine latest Defold release"
  exit 1
fi

echo "Latest release:     ${latest}"

defold_url="https://github.com/defold/defold/releases/download/${latest}/Defold-x86_64-linux.tar.gz"
bob_url="https://github.com/defold/defold/releases/download/${latest}/bob.jar"
gdc_url="https://github.com/defold/defold/releases/download/${latest}/gdc-linux"

echo "⬇️  Prefetching Defold artefacts for hash comparison..."
latest_defold_hash=$(nix store prefetch-file --json --hash-type sha256 "$defold_url" | jq -r '.hash')
latest_bob_hash=$(nix store prefetch-file --json --hash-type sha256 "$bob_url" | jq -r '.hash')

# Defold intermittently stops publishing the gdc-linux artefact, so a genuine
# 404 must skip defold-gdc rather than fail the run. Probe the status first so
# only a confirmed missing artefact is treated as absent; any other outcome
# (network error, 5xx) falls through to the prefetch, which fails the run.
# No -f here: curl must report the real status code on a 404 rather than exit
# non-zero. A connection failure yields 000, which is not treated as missing.
gdc_status=$(curl -sSL -o /dev/null -w '%{http_code}' -I "$gdc_url" || echo "000")
if [[ "$gdc_status" == "404" ]]; then
  echo "⏭️  gdc-linux artefact not published for ${latest} (HTTP 404)"
  latest_gdc_hash=""
else
  latest_gdc_hash=$(nix store prefetch-file --json --hash-type sha256 "$gdc_url" | jq -r '.hash')
fi

echo "Latest defold hash:     ${latest_defold_hash}"
echo "Latest defold-bob hash: ${latest_bob_hash}"
echo "Latest defold-gdc hash: ${latest_gdc_hash}"

gdc_matches=true
if [[ -n "$latest_gdc_hash" ]]; then
  [[ "$current_gdc_version" == "$latest" && "$current_gdc_hash" == "$latest_gdc_hash" ]] || gdc_matches=false
fi
if [[ "$current_defold_version" == "$latest" \
   && "$current_bob_version" == "$latest" \
   && "$current_defold_hash" == "$latest_defold_hash" \
   && "$current_bob_hash" == "$latest_bob_hash" \
   && "$gdc_matches" == "true" ]]; then
  echo "✅ All Defold packages are up to date"
  echo "updated=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

sed -i 's/^  version = ".*"/  version = "'"${latest}"'"/' "$DEFOLD_NIX"
sed -i 's|hash = "sha256-[^"]*"|hash = "'"${latest_defold_hash}"'"|' "$DEFOLD_NIX"
echo "✅ Updated ${DEFOLD_NIX}"

sed -i 's/^  version = ".*"/  version = "'"${latest}"'"/' "$BOB_NIX"
sed -i 's|hash = "sha256-[^"]*"|hash = "'"${latest_bob_hash}"'"|' "$BOB_NIX"
echo "✅ Updated ${BOB_NIX}"

files="${DEFOLD_NIX} ${BOB_NIX}"
if [[ -n "$latest_gdc_hash" ]]; then
  sed -i 's/^  version = ".*"/  version = "'"${latest}"'"/' "$GDC_NIX"
  sed -i 's|hash = "sha256-[^"]*"|hash = "'"${latest_gdc_hash}"'"|' "$GDC_NIX"
  echo "✅ Updated ${GDC_NIX}"
  files="${files} ${GDC_NIX}"
else
  echo "⏭️  Skipping ${GDC_NIX} (gdc-linux artefact not available)"
fi

# shellcheck disable=SC2086
git diff $files

# Include a short hash in the version so the branch name changes on a re-push.
short_hash=$(echo "${latest_defold_hash}" | cut -c8-15)
{
  echo "updated=true"
  echo "version=${latest}-${short_hash}"
  echo "files=${files}"
} >> "$GITHUB_OUTPUT"
