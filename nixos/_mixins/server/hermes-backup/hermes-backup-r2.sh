set -euo pipefail

umask 077

readonly stateDir="/var/lib/hermes"
readonly cacheDir="/var/cache/hermes-backup"
readonly workDir="${cacheDir}/work"
readonly snapshotDir="${workDir}/snapshot"
readonly artifactsDir="${workDir}/artifacts"
readonly rcloneConfigDir="${workDir}/rclone"
readonly rcloneConfigPath="${rcloneConfigDir}/rclone.conf"
readonly lockPath="${cacheDir}/hermes-backup.lock"

mkdir -p "${cacheDir}" "${snapshotDir}" "${artifactsDir}" "${rcloneConfigDir}"
exec 9>"${lockPath}"
flock -n 9 || {
  echo "Another Hermes backup run is already in progress." >&2
  exit 1
}

requiredVars=(
  R2_BUCKET
  R2_ENDPOINT
  R2_ACCESS_KEY_ID
  R2_SECRET_ACCESS_KEY
  RCLONE_CRYPT_PASSWORD
  RCLONE_CRYPT_PASSWORD2
)

for varName in "${requiredVars[@]}"; do
  if [ -z "${!varName:-}" ]; then
    echo "Missing required environment variable: ${varName}" >&2
    exit 1
  fi
done

readonly timestamp="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
readonly hostName="$(hostname -s)"
readonly archiveName="${timestamp}.tar.zst"
readonly manifestName="${timestamp}.manifest.json"
readonly archivePath="${artifactsDir}/${archiveName}"
readonly manifestPath="${artifactsDir}/${manifestName}"
readonly remotePrefix="hermes-encrypted:${hostName}/backups"

hermesWasRunning=0

cleanup() {
  local exitCode="$1"

  if [ "${hermesWasRunning}" -eq 1 ] && ! systemctl is-active --quiet hermes-agent.service; then
    echo "Restarting hermes-agent.service after backup interruption." >&2
    systemctl start hermes-agent.service || true
  fi

  rm -rf "${snapshotDir}" "${rcloneConfigDir}"

  if [ "${exitCode}" -eq 0 ]; then
    find "${artifactsDir}" -maxdepth 1 -type f -mtime +2 -delete
  fi
}

trap 'cleanup "$?"' EXIT

if systemctl is-active --quiet hermes-agent.service; then
  hermesWasRunning=1
  echo "Stopping hermes-agent.service for a consistent snapshot."
  systemctl stop hermes-agent.service
fi

rm -rf "${snapshotDir}"
mkdir -p "${snapshotDir}"
rsync -a --delete --numeric-ids "${stateDir}/" "${snapshotDir}/"

if [ "${hermesWasRunning}" -eq 1 ]; then
  echo "Starting hermes-agent.service after snapshot."
  systemctl start hermes-agent.service
  hermesWasRunning=0
fi

cryptPassword="$(rclone obscure "${RCLONE_CRYPT_PASSWORD}")"
cryptPassword2="$(rclone obscure "${RCLONE_CRYPT_PASSWORD2}")"

cat > "${rcloneConfigPath}" <<EOF
[hermes-r2]
type = s3
provider = Cloudflare
access_key_id = ${R2_ACCESS_KEY_ID}
secret_access_key = ${R2_SECRET_ACCESS_KEY}
region = auto
endpoint = ${R2_ENDPOINT}
acl = private

[hermes-encrypted]
type = crypt
remote = hermes-r2:${R2_BUCKET}/hermes
password = ${cryptPassword}
password2 = ${cryptPassword2}
filename_encryption = standard
directory_name_encryption = true
EOF

rm -f "${archivePath}" "${manifestPath}"

tar \
  --use-compress-program="zstd -T0 -19" \
  -cf "${archivePath}" \
  -C "${snapshotDir}" \
  .

archiveSizeBytes="$(stat -c '%s' "${archivePath}")"
archiveSha256="$(sha256sum "${archivePath}" | cut -d ' ' -f 1)"

jq -n \
  --arg timestamp "${timestamp}" \
  --arg hostname "${hostName}" \
  --arg sourcePath "${stateDir}" \
  --arg archiveName "${archiveName}" \
  --arg sha256 "${archiveSha256}" \
  --argjson sizeBytes "${archiveSizeBytes}" \
  '{
    timestamp: $timestamp,
    hostname: $hostname,
    source_path: $sourcePath,
    archive_name: $archiveName,
    archive_size_bytes: $sizeBytes,
    archive_sha256: $sha256
  }' > "${manifestPath}"

rclone copyto "${archivePath}" "${remotePrefix}/${archiveName}" --config "${rcloneConfigPath}"
rclone copyto "${manifestPath}" "${remotePrefix}/${manifestName}" --config "${rcloneConfigPath}"

archiveListing="$(rclone lsjson "${remotePrefix}/${archiveName}" --config "${rcloneConfigPath}")"
manifestListing="$(rclone lsjson "${remotePrefix}/${manifestName}" --config "${rcloneConfigPath}")"

archiveRemoteSize="$(printf '%s' "${archiveListing}" | jq -r 'if length == 1 then .[0].Size else empty end')"
manifestCount="$(printf '%s' "${manifestListing}" | jq 'length')"

if [ -z "${archiveRemoteSize}" ] || [ "${archiveRemoteSize}" != "${archiveSizeBytes}" ]; then
  echo "Remote archive verification failed for ${archiveName}." >&2
  exit 1
fi

if [ "${manifestCount}" != "1" ]; then
  echo "Remote manifest verification failed for ${manifestName}." >&2
  exit 1
fi

rm -f "${archivePath}" "${manifestPath}"

echo "Hermes backup uploaded successfully: ${remotePrefix}/${archiveName} (${archiveSizeBytes} bytes, sha256 ${archiveSha256})"
