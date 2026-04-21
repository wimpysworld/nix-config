set -euo pipefail

umask 077

loadBackupEnvironment
ensureCacheDirectories

verifyDir=""

cleanup() {
  if [ -n "${verifyDir}" ]; then
    rm -rf "${verifyDir}"
  fi
  cleanupRcloneConfig
}

trap cleanup EXIT

createRcloneConfig
verifyDir="$(mktemp -d "${workDir}/verify.XXXXXX")"

if [ "$#" -gt 1 ]; then
  die "Usage: hermes-backup-verify-r2 [backup-timestamp-or-archive-name]"
fi

if [ "$#" -eq 1 ]; then
  archiveName="$(normaliseArchiveSelection "$1")"
else
  archiveName="$(selectLatestArchiveName)"
fi

manifestName="$(manifestNameFromArchive "${archiveName}")"
logPhase "Verifying remote artefacts for ${archiveName}"
remoteArchiveSize="$(verifyRemoteBackupPair "${archiveName}")"

logPhase "Downloading ${archiveName} and ${manifestName}"
mapfile -t downloadedPaths < <(downloadBackupPair "${archiveName}" "${verifyDir}")
archivePath="${downloadedPaths[0]}"
manifestPath="${downloadedPaths[1]}"

logPhase "Validating manifest, archive hash, and archive structure"
verifyBackupArchive "${archiveName}" "${archivePath}" "${manifestPath}" "$(currentHostName)"

printf 'Hermes backup verification passed: %s (%s bytes)\n' "${archiveName}" "${remoteArchiveSize}"
