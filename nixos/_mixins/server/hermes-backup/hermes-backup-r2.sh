set -euo pipefail

umask 077

loadBackupEnvironment
ensureCacheDirectories
acquireBackupLock

readonly timestamp="$(timestampNowUtc)"
readonly hostName="$(currentHostName)"
readonly archiveName="$(archiveNameFromTimestamp "${timestamp}")"
readonly manifestName="$(manifestNameFromArchive "${archiveName}")"
readonly archivePath="${artifactsDir}/${archiveName}"
readonly manifestPath="${artifactsDir}/${manifestName}"
readonly remoteBackupPrefix="$(remotePrefix)"

cleanup() {
  local exitCode="$1"
  local artifactPath

  rm -rf "${snapshotDir}"
  cleanupRcloneConfig

  for artifactPath in "${archivePath}" "${manifestPath}"; do
    rm -f "${artifactPath}"
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
    logPhase "Skipping missing SQLite database: ${sourcePath}"
    return 0
  fi

  mkdir -p "$(dirname "${targetPath}")"
  sqlite3 "${sourcePath}" ".backup '${targetPath}'"
}

trap 'cleanup "$?"' EXIT
createRcloneConfig

logPhase "Starting Hermes backup for ${hostName}"
logPhase "Phase: snapshot"
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

logPhase "Phase: SQLite capture"
for databaseName in "${sqliteDatabases[@]}"; do
  backupSqliteDatabase "${databaseName}"
done

logPhase "Phase: archive creation"
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

logPhase "Phase: upload"
rclone copyto "${archivePath}" "$(remoteArchivePath "${archiveName}")" --config "${rcloneConfigPath}"
rclone copyto "${manifestPath}" "$(remoteManifestPath "${archiveName}")" --config "${rcloneConfigPath}"

logPhase "Phase: verification"
archiveRemoteSize="$(verifyRemoteBackupPair "${archiveName}")"

if [ "${archiveRemoteSize}" != "${archiveSizeBytes}" ]; then
  die "Remote archive size mismatch for ${archiveName}: remote=${archiveRemoteSize}, local=${archiveSizeBytes}."
fi

rm -f "${archivePath}" "${manifestPath}"

printf 'Hermes backup uploaded successfully: %s/%s (%s bytes, sha256 %s)\n' \
  "${remoteBackupPrefix}" \
  "${archiveName}" \
  "${archiveSizeBytes}" \
  "${archiveSha256}"
