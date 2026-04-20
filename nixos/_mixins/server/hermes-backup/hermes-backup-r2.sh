set -euo pipefail

umask 077

readonly stateDir="/var/lib/hermes"
readonly hermesHome="${stateDir}/.hermes"
readonly cacheDir="/var/cache/hermes-backup"
readonly workDir="${cacheDir}/work"
readonly snapshotDir="${workDir}/snapshot"
readonly artifactsDir="${workDir}/artifacts"
readonly rcloneConfigDir="${workDir}/rclone"
readonly rcloneConfigPath="${rcloneConfigDir}/rclone.conf"
readonly lockPath="${cacheDir}/hermes-backup.lock"
readonly sqliteDatabases=(
  "state.db"
  "memory_store.db"
)

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

timestamp="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
readonly timestamp
hostName="$(hostname -s)"
readonly hostName
readonly archiveName="${timestamp}.tar.zst"
readonly manifestName="${timestamp}.manifest.json"
readonly archivePath="${artifactsDir}/${archiveName}"
readonly manifestPath="${artifactsDir}/${manifestName}"
readonly remotePrefix="hermes-encrypted:${hostName}/backups"

cleanup() {
  local exitCode="$1"
  local artifactPath

  rm -rf "${snapshotDir}" "${rcloneConfigDir}"

  for artifactPath in "${archivePath:-}" "${manifestPath:-}"; do
    if [ -n "${artifactPath}" ]; then
      rm -f "${artifactPath}"
    fi
  done

  if [ "${exitCode}" -eq 0 ]; then
    find "${artifactsDir}" -maxdepth 1 -type f -mtime +2 -delete
  fi
}

backupSqliteDatabase() {
  local databaseName="$1"
  local sourcePath="${hermesHome}/${databaseName}"
  local targetPath="${snapshotDir}/.hermes/${databaseName}"

  if [ ! -f "${sourcePath}" ]; then
    echo "Skipping missing SQLite database: ${sourcePath}"
    return 0
  fi

  mkdir -p "$(dirname "${targetPath}")"
  sqlite3 "${sourcePath}" ".backup '${targetPath}'"
}

trap 'cleanup "$?"' EXIT

rm -rf "${snapshotDir}"
mkdir -p "${snapshotDir}"

rsync -a --delete --numeric-ids \
  --exclude='/.hermes/state.db' \
  --exclude='/.hermes/state.db-wal' \
  --exclude='/.hermes/state.db-shm' \
  --exclude='/.hermes/memory_store.db' \
  --exclude='/.hermes/memory_store.db-wal' \
  --exclude='/.hermes/memory_store.db-shm' \
  "${stateDir}/" "${snapshotDir}/"

for databaseName in "${sqliteDatabases[@]}"; do
  backupSqliteDatabase "${databaseName}"
done

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
