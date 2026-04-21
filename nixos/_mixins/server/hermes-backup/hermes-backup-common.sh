readonly stateDir="/var/lib/hermes"
# shellcheck disable=SC2034
readonly hermesHome="${stateDir}/.hermes"
readonly cacheDir="/var/cache/hermes-backup"
readonly workDir="${cacheDir}/work"
# shellcheck disable=SC2034
readonly snapshotDir="${workDir}/snapshot"
readonly artifactsDir="${workDir}/artifacts"
rcloneConfigDir=""
rcloneConfigPath=""
readonly lockPath="${cacheDir}/hermes-backup.lock"
readonly archiveExtension=".tar.zst"
readonly manifestSuffix=".manifest.json"
# shellcheck disable=SC2034
readonly sqliteDatabases=(
	"state.db"
	"memory_store.db"
)

logPhase() {
	printf '[hermes-backup] %s\n' "$*" >&2
}

die() {
	printf '[hermes-backup] ERROR: %s\n' "$*" >&2
	exit 1
}

ensureCacheDirectories() {
	mkdir -p "${cacheDir}" "${workDir}" "${artifactsDir}"
}

cleanupRcloneConfig() {
	if [ -n "${rcloneConfigDir}" ]; then
		rm -rf "${rcloneConfigDir}"
	fi

	rcloneConfigDir=""
	rcloneConfigPath=""
}

acquireBackupLock() {
	exec 9>"${lockPath}"
	flock -n 9 || die "Another Hermes backup run is already in progress."
}

loadEnvVarFromFile() {
	local varName="$1"
	local fileVarName="${varName}_FILE"
	local filePath="${!fileVarName:-}"

	if [ -n "${!varName:-}" ] || [ -z "${filePath}" ]; then
		return 0
	fi

	if [ ! -r "${filePath}" ]; then
		die "Missing readable environment file for ${varName}: ${filePath}"
	fi

	export "${varName}=$(<"${filePath}")"
}

loadBackupEnvironment() {
	if [ -n "${HERMES_BACKUP_ENV_FILE:-}" ] && [ -r "${HERMES_BACKUP_ENV_FILE}" ]; then
		set -a
		# shellcheck source=/dev/null
		# shellcheck disable=SC1090
		. "${HERMES_BACKUP_ENV_FILE}"
		set +a
	fi

	loadEnvVarFromFile R2_BUCKET
	loadEnvVarFromFile R2_ENDPOINT
	loadEnvVarFromFile R2_ACCESS_KEY_ID
	loadEnvVarFromFile R2_SECRET_ACCESS_KEY
	loadEnvVarFromFile BACKUP_CRYPT_PASSWORD
	loadEnvVarFromFile BACKUP_CRYPT_PASSWORD2

	if [ -z "${BACKUP_CRYPT_PASSWORD:-}" ] && [ -n "${RCLONE_CRYPT_PASSWORD:-}" ]; then
		export BACKUP_CRYPT_PASSWORD="${RCLONE_CRYPT_PASSWORD}"
	fi

	if [ -z "${BACKUP_CRYPT_PASSWORD2:-}" ] && [ -n "${RCLONE_CRYPT_PASSWORD2:-}" ]; then
		export BACKUP_CRYPT_PASSWORD2="${RCLONE_CRYPT_PASSWORD2}"
	fi

	requiredVars=(
		R2_BUCKET
		R2_ENDPOINT
		R2_ACCESS_KEY_ID
		R2_SECRET_ACCESS_KEY
		BACKUP_CRYPT_PASSWORD
		BACKUP_CRYPT_PASSWORD2
	)

	for varName in "${requiredVars[@]}"; do
		if [ -z "${!varName:-}" ]; then
			die "Missing required environment variable: ${varName}"
		fi
	done
}

currentHostName() {
	hostname -s
}

timestampNowUtc() {
	date -u +%Y-%m-%dT%H-%M-%SZ
}

archiveNameFromTimestamp() {
	printf '%s%s\n' "$1" "${archiveExtension}"
}

manifestNameFromArchive() {
	local archiveName="$1"

	case "${archiveName}" in
	*"${archiveExtension}")
		printf '%s%s\n' "${archiveName%"${archiveExtension}"}" "${manifestSuffix}"
		;;
	*)
		die "Backup name must end with ${archiveExtension}: ${archiveName}"
		;;
	esac
}

normaliseArchiveSelection() {
	local selection="${1:-}"

	if [ -z "${selection}" ]; then
		die "A backup timestamp or archive name is required."
	fi

	case "${selection}" in
	*"${archiveExtension}")
		printf '%s\n' "${selection}"
		;;
	*"${manifestSuffix}")
		die "Pass the backup archive name or timestamp, not the manifest name: ${selection}"
		;;
	*)
		printf '%s%s\n' "${selection}" "${archiveExtension}"
		;;
	esac
}

remotePrefix() {
	printf 'hermes-encrypted:%s/backups\n' "$(currentHostName)"
}

remoteArchivePath() {
	printf '%s/%s\n' "$(remotePrefix)" "$1"
}

remoteManifestPath() {
	printf '%s/%s\n' "$(remotePrefix)" "$(manifestNameFromArchive "$1")"
}

createRcloneConfig() {
	local cryptPassword cryptPassword2

	rcloneConfigDir="$(mktemp -d "${workDir}/rclone.XXXXXX")"
	rcloneConfigPath="${rcloneConfigDir}/rclone.conf"

	cryptPassword="$(printf '%s\n' "${BACKUP_CRYPT_PASSWORD}" | rclone obscure -)"
	cryptPassword2="$(printf '%s\n' "${BACKUP_CRYPT_PASSWORD2}" | rclone obscure -)"

	cat >"${rcloneConfigPath}" <<EOF
[hermes-r2]
type = s3
provider = Cloudflare
access_key_id = ${R2_ACCESS_KEY_ID}
secret_access_key = ${R2_SECRET_ACCESS_KEY}
region = auto
endpoint = ${R2_ENDPOINT}
acl = private
no_check_bucket = true

[hermes-encrypted]
type = crypt
remote = hermes-r2:${R2_BUCKET}/hermes
password = ${cryptPassword}
password2 = ${cryptPassword2}
filename_encryption = standard
directory_name_encryption = true
EOF
}

remoteObjectCount() {
	rclone lsjson "$1" --config "${rcloneConfigPath}" | jq 'length'
}

remoteObjectSize() {
	rclone lsjson "$1" --config "${rcloneConfigPath}" | jq -r 'if length == 1 then .[0].Size else empty end'
}

listRemoteBackupArchives() {
	rclone lsf "$(remotePrefix)" --config "${rcloneConfigPath}" --files-only |
		grep -E '\.tar\.zst$' ||
		true
}

listRemoteBackupManifests() {
	rclone lsf "$(remotePrefix)" --config "${rcloneConfigPath}" --files-only |
		grep -E '\.manifest\.json$' ||
		true
}

selectLatestArchiveName() {
	local manifestName

	manifestName="$(listRemoteBackupManifests | sort | tail -n 1)"
	if [ -z "${manifestName}" ]; then
		die "No complete Hermes backups were found under $(remotePrefix)."
	fi

	printf '%s%s\n' "${manifestName%"${manifestSuffix}"}" "${archiveExtension}"
}

downloadBackupPair() {
	local archiveName="$1"
	local downloadDir="$2"
	local archivePath="${downloadDir}/${archiveName}"
	local manifestPath

	manifestPath="${downloadDir}/$(manifestNameFromArchive "${archiveName}")"

	mkdir -p "${downloadDir}"

	rclone copyto \
		"$(remoteArchivePath "${archiveName}")" \
		"${archivePath}" \
		--config "${rcloneConfigPath}"

	rclone copyto \
		"$(remoteManifestPath "${archiveName}")" \
		"${manifestPath}" \
		--config "${rcloneConfigPath}"

	printf '%s\n%s\n' "${archivePath}" "${manifestPath}"
}

verifyRemoteBackupPair() {
	local archiveName="$1"
	local manifestName remoteArchiveSize manifestCount

	manifestName="$(manifestNameFromArchive "${archiveName}")"
	remoteArchiveSize="$(remoteObjectSize "$(remoteArchivePath "${archiveName}")")"
	manifestCount="$(remoteObjectCount "$(remoteManifestPath "${archiveName}")")"

	if [ -z "${remoteArchiveSize}" ]; then
		die "Remote archive verification failed for ${archiveName}."
	fi

	if [ "${manifestCount}" != "1" ]; then
		die "Remote manifest verification failed for ${manifestName}."
	fi

	printf '%s\n' "${remoteArchiveSize}"
}

verifyBackupArchive() {
	local archiveName="$1"
	local archivePath="$2"
	local manifestPath="$3"
	local expectedHost="$4"
	local manifestArchiveName manifestHost manifestSha256 manifestSizeBytes actualSizeBytes actualSha256

	manifestArchiveName="$(jq -r '.archive_name // empty' "${manifestPath}")"
	manifestHost="$(jq -r '.hostname // empty' "${manifestPath}")"
	manifestSha256="$(jq -r '.archive_sha256 // empty' "${manifestPath}")"
	manifestSizeBytes="$(jq -r '.archive_size_bytes // empty' "${manifestPath}")"

	[ -n "${manifestArchiveName}" ] || die "Backup manifest is missing archive_name."
	[ -n "${manifestHost}" ] || die "Backup manifest is missing hostname."
	[ -n "${manifestSha256}" ] || die "Backup manifest is missing archive_sha256."
	[ -n "${manifestSizeBytes}" ] || die "Backup manifest is missing archive_size_bytes."

	if [ "${manifestArchiveName}" != "${archiveName}" ]; then
		die "Backup manifest archive_name does not match ${archiveName}."
	fi

	if [ "${manifestHost}" != "${expectedHost}" ]; then
		die "Backup manifest hostname ${manifestHost} does not match ${expectedHost}."
	fi

	if ! [[ "${manifestSha256}" =~ ^[0-9a-f]{64}$ ]]; then
		die "Backup manifest archive_sha256 is not a valid SHA-256 digest."
	fi

	if ! [[ "${manifestSizeBytes}" =~ ^[0-9]+$ ]]; then
		die "Backup manifest archive_size_bytes is not an integer."
	fi

	actualSizeBytes="$(stat -c '%s' "${archivePath}")"
	actualSha256="$(sha256sum "${archivePath}" | cut -d ' ' -f 1)"

	if [ "${manifestSizeBytes}" != "${actualSizeBytes}" ]; then
		die "Archive size mismatch for ${archiveName}: manifest=${manifestSizeBytes}, actual=${actualSizeBytes}."
	fi

	if [ "${manifestSha256}" != "${actualSha256}" ]; then
		die "Archive SHA-256 mismatch for ${archiveName}."
	fi

	processBackupArchive verify "${archivePath}"
}

processBackupArchive() {
	local mode="$1"
	local archivePath="$2"
	local destinationPath="${3:-}"

	if [ "${mode}" = "extract" ] && [ -z "${destinationPath}" ]; then
		die "Archive extraction requires a destination path."
	fi

	python3 - "${mode}" "${archivePath}" "${destinationPath}" <<'PY'
import os
import pathlib
import posixpath
import shutil
import subprocess
import sys
import tarfile

mode = sys.argv[1]
archive_path = sys.argv[2]
destination_path = os.path.realpath(sys.argv[3]) if mode == "extract" and sys.argv[3] else None
found_hermes = False
deferred_directories = []
pending_error = None
proc = subprocess.Popen(["zstd", "-d", "-q", "-c", archive_path], stdout=subprocess.PIPE)

try:
    assert proc.stdout is not None
    with tarfile.open(fileobj=proc.stdout, mode="r|") as archive:
        for member in archive:
            name = member.name
            if name in {"", "."}:
                continue

            normalised = posixpath.normpath(name)
            parts = [part for part in pathlib.PurePosixPath(normalised).parts if part not in {"", "."}]

            if name.startswith("/") or normalised == ".." or any(part == ".." for part in parts):
                raise SystemExit(f"Unsafe archive path: {name}")

            if member.issym() or member.islnk():
                raise SystemExit(f"Refusing archive link entry: {name}")

            if member.ischr() or member.isblk() or member.isfifo():
                raise SystemExit(f"Refusing special archive entry: {name}")

            if parts and parts[0] == ".hermes":
                found_hermes = True

            if mode != "extract":
                continue

            relative_path = os.path.join(*parts) if parts else ""
            target_path = os.path.realpath(os.path.join(destination_path, relative_path)) if relative_path else destination_path

            if target_path != destination_path and not target_path.startswith(destination_path + os.sep):
                raise SystemExit(f"Archive entry escapes destination: {name}")

            if member.isdir():
                os.makedirs(target_path, exist_ok=True)
                deferred_directories.append((target_path, member.mode & 0o777, member.mtime))
                continue

            if not member.isfile():
                raise SystemExit(f"Unsupported archive entry: {name}")

            os.makedirs(os.path.dirname(target_path), exist_ok=True)
            source = archive.extractfile(member)
            if source is None:
                raise SystemExit(f"Unable to read archive entry: {name}")

            with source, open(target_path, "wb") as destination:
                shutil.copyfileobj(source, destination)

            os.chmod(target_path, member.mode & 0o777)
            os.utime(target_path, (member.mtime, member.mtime), follow_symlinks=False)

    for target_path, mode_bits, mtime in reversed(deferred_directories):
        os.chmod(target_path, mode_bits)
        os.utime(target_path, (mtime, mtime), follow_symlinks=False)
except BaseException as error:
    pending_error = error
    raise
finally:
    if proc.stdout is not None:
        proc.stdout.close()
    exit_code = proc.wait()
    if exit_code != 0 and pending_error is None:
        action = "extracting" if mode == "extract" else "reading"
        raise SystemExit(f"zstd failed while {action} {archive_path}: exit code {exit_code}")

if not found_hermes:
    raise SystemExit("Archive does not contain the expected .hermes data.")
PY
}

prepareRestoreDestination() {
	local requestedPath="$1"
	local resolvedPath resolvedParent statePath

	if [ -z "${requestedPath}" ]; then
		die "A destination path argument is required."
	fi

	case "${requestedPath}" in
	/*) ;;
	*)
		die "Destination path must be absolute to avoid ambiguous restores: ${requestedPath}"
		;;
	esac

	resolvedPath="$(realpath -m "${requestedPath}")"
	resolvedParent="$(dirname "${resolvedPath}")"
	statePath="$(realpath -m "${stateDir}")"

	case "${resolvedPath}" in
	/ | /var | /var/lib)
		die "Refusing to restore into a dangerous top-level path: ${resolvedPath}"
		;;
	esac

	if [ ! -d "${resolvedParent}" ]; then
		die "Destination parent directory does not exist: ${resolvedParent}"
	fi

	case "${resolvedPath}" in
	"${statePath}" | "${statePath}"/*)
		die "Refusing to restore into the live Hermes state path: ${resolvedPath}"
		;;
	esac

	case "$(realpath -m "${resolvedParent}")" in
	"${statePath}" | "${statePath}"/*)
		die "Refusing to restore beneath the live Hermes state path: ${resolvedParent}"
		;;
	esac

	if [ -L "${requestedPath}" ] || [ -L "${resolvedPath}" ]; then
		die "Destination path must not be a symbolic link: ${requestedPath}"
	fi

	if [ -e "${resolvedPath}" ]; then
		if [ ! -d "${resolvedPath}" ]; then
			die "Destination exists and is not a directory: ${resolvedPath}"
		fi

		if [ -n "$(find "${resolvedPath}" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
			die "Destination directory must be empty before restore: ${resolvedPath}"
		fi
	else
		mkdir -p "${resolvedPath}"
	fi

	printf '%s\n' "${resolvedPath}"
}

extractBackupArchive() {
	local archivePath="$1"
	local destinationPath="$2"

	processBackupArchive extract "${archivePath}" "${destinationPath}"
}
