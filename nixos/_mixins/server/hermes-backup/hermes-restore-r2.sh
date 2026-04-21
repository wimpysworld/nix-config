set -euo pipefail

umask 077

if [ "$#" -ne 2 ]; then
  die "Usage: hermes-restore-r2 <backup-timestamp-or-archive-name> <absolute-destination-path>"
fi

archiveName="$(normaliseArchiveSelection "$1")"
destinationPath="$(prepareRestoreDestination "$2")"

loadBackupEnvironment
ensureCacheDirectories

restoreDir=""

cleanup() {
  if [ -n "${restoreDir}" ]; then
    rm -rf "${restoreDir}"
  fi
  cleanupRcloneConfig
}

trap cleanup EXIT

createRcloneConfig
restoreDir="$(mktemp -d "${workDir}/restore.XXXXXX")"

logPhase "Checking remote artefacts for ${archiveName}"
verifyRemoteBackupPair "${archiveName}" > /dev/null

logPhase "Downloading ${archiveName}"
mapfile -t downloadedPaths < <(downloadBackupPair "${archiveName}" "${restoreDir}")
archivePath="${downloadedPaths[0]}"
manifestPath="${downloadedPaths[1]}"

logPhase "Validating archive before restore"
verifyBackupArchive "${archiveName}" "${archivePath}" "${manifestPath}" "$(currentHostName)"

logPhase "Extracting ${archiveName} into ${destinationPath}"
extractBackupArchive "${archivePath}" "${destinationPath}"

printf 'Hermes backup restore completed: %s -> %s\n' "${archiveName}" "${destinationPath}"
