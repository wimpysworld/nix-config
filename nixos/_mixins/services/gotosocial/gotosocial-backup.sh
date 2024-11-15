#!/usr/bin/env bash
# Backup script for GoToSocial
# - exports data, backs up the SQLite database, and media files
# - optionally encrypts sensitive data for secure offsite storage
# - https://docs.gotosocial.org/en/latest/admin/backup_and_restore/
# - https://litestream.io/alternatives/cron/

set +e          # Disable errexit
set +u          # Disable nounset
set +o pipefail # Disable pipefail

# Default configuration
CONFIG_DEFAULTS=(
    'BACKUP_ROOT=/mnt/data/backup/gotosocial'
    'GTS_CONFIG=/etc/gotosocial/config.yaml'
    'GTS_DB=/var/lib/gotosocial/database.sqlite'
    'RETENTION_DAYS=28'
    'PASSPHRASE='
    'NTFY_SERVER='
    'NTFY_TOPIC='
)

# Load configuration from file if it exists
CONFIG_FILE="/etc/gotosocial-backup.conf"
if [ -f "${CONFIG_FILE}" ]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
fi

# Set defaults for any unset variables
for default in "${CONFIG_DEFAULTS[@]}"; do
    var_name="${default%%=*}"
    var_default="${default#*=}"
    # Only set if not already set by environment or config file
    if [ -z "${!var_name}" ]; then
        declare "${var_name}=${var_default}"
    fi
done

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root" >&2
    exit 1
fi

# No need to edit below this line
STAMP=$(date +%Y%m%d_%H%M%S)
TODAY=$(echo "${STAMP}" | cut -d'_' -f 1)
BACKUP_DIR="${BACKUP_ROOT}/${STAMP}"
DB_BACKUP="${BACKUP_DIR}/database.sqlite"
EXPORT_BACKUP="${BACKUP_DIR}/export.json"
EXPORT_TEMP="/tmp/gotosocial_export_${STAMP}.json"
LATEST_LINK="${BACKUP_ROOT}/latest"
LOGFILE="${BACKUP_ROOT}/backup.log"
LOGLINES=4096

# Function to compress and optionally encrypt a file
function process_backup() {
    local input_file="${1}"
    local remove_source="${2:-true}"

    if [ ! -f "${input_file}" ]; then
        handle_error "Input file ${input_file} not found"
    fi

    if [ -n "${PASSPHRASE}" ]; then
        # Compress and encrypt in one pipeline
        if gzip -c "${input_file}" | openssl enc -aes-256-cbc -salt -pbkdf2 -out "${input_file}.gz.enc" -pass "pass:${PASSPHRASE}"; then
            log_message "Successfully compressed and encrypted ${input_file}"
            # Remove the source file if requested
            if [ "${remove_source}" = "true" ]; then
                rm -f "${input_file}"
            fi
            return 0
        else
            handle_error "Failed to compress and encrypt ${input_file}"
        fi
    else
        # Just compress the file
        if gzip -f "${input_file}"; then
            log_message "Successfully compressed ${input_file}"
            return 0
        else
            handle_error "Failed to compress ${input_file}"
        fi
    fi
}

# Function to get the expected backup extension
function get_backup_extension() {
    if [ -n "${PASSPHRASE}" ]; then
        echo "gz.enc"
    else
        echo "gz"
    fi
}

# Function to rotate log file
function rotate_log() {
    if [ -f "${LOGFILE}" ]; then
        log_message "Rotating log file (keeping last ${LOGLINES} lines)"
        local tmp_log="/tmp/backup_log_${STAMP}.tmp"
        tail -n "${LOGLINES}" "${LOGFILE}" > "${tmp_log}"
        mv "${tmp_log}" "${LOGFILE}"
        chmod 600 "${LOGFILE}"
    fi
}

# Function to execute gotosocial admin
# NixOS installs the gotosocial-admin helper, so use it if available
function gts_admin() {
    local command="${1}"
    # Remove the first argument, leaving the rest in $@
    shift
    if [ -x /run/current-system/sw/bin/gotosocial-admin ]; then
        /run/current-system/sw/bin/gotosocial-admin "$command" "${@}"
    else
        gotosocial --config-path "${GTS_CONFIG}" admin "${command}" "${@}"
    fi
}

# Simple notification function
function send_ntfy() {
    local error_message="${1}"
    if [ -n "${NTFY_SERVER}" ] && [ -n "${NTFY_TOPIC}" ]; then
        curl -d "${error_message}" "https://${NTFY_SERVER}/${NTFY_TOPIC}"
    fi
}

# Function to log messages
function log_message() {
    echo "$(date '+%Y/%m/%d %H:%M:%S') ${1}" | tee -a "${LOGFILE}"
}

# Function to handle errors
function handle_error() {
    log_message "ERROR: ${1}"
    send_ntfy "GoToSocial backup failed: ${1}"
    exit 1
}

# Function to clean up temporary files
function cleanup() {
    [ -f "${TMPFILE}" ] && rm -f "${TMPFILE}"
    [ -f "${EXPORT_TEMP}" ] && rm -f "${EXPORT_TEMP}"
    log_message "Cleanup completed"
    rotate_log
}
trap cleanup EXIT

# Rotate log file at the start of backup
rotate_log

# Log encryption status
if [ -n "${PASSPHRASE}" ]; then
    log_message "Encryption enabled - backups will be encrypted"
else
    log_message "Encryption disabled - backups will only be compressed"
fi

# Check if running under sudo and warn about potential environment issues
if [ -n "${SUDO_USER}" ]; then
    log_message "Warning: Script is running via sudo. Environment variables from the user environment may not be preserved."
fi

# Check if we're using gotosocial-admin or gotosocial
if [ -x /run/current-system/sw/bin/gotosocial-admin ]; then
    log_message "Using gotosocial-admin"
elif command -v gotosocial >/dev/null 2>&1; then
    log_message "Using gotosocial with ${GTS_CONFIG}"
else
    handle_error "gotosocial not found in the PATH"
fi

# Ensure backup root directory exists
mkdir -p "${BACKUP_ROOT}"
chmod 700 "${BACKUP_ROOT}"

# Create new backup directory
mkdir -p "${BACKUP_DIR}" || handle_error "Failed to create backup directory"
chmod 700 "${BACKUP_DIR}"

# Check if source database exists and is readable
if [ ! -r "${GTS_DB}" ]; then
    handle_error "Database file ${GTS_DB} does not exist or is not readable"
fi

# Export GoToSocial data
log_message "Starting GoToSocial export"
if gts_admin "export" "--path" "${EXPORT_TEMP}"; then
    log_message "GoToSocial export completed successfully"
    # Move export file to backup directory
    if mv "${EXPORT_TEMP}" "${EXPORT_BACKUP}"; then
        log_message "Export file moved to backup directory"
        # Process the export file
        process_backup "${EXPORT_BACKUP}"
    else
        handle_error "Failed to move export file to backup directory"
    fi
else
    handle_error "GoToSocial export failed"
fi

# Backup SQLite database
log_message "Starting database backup"

# Create database backup with VACUUM
if sqlite3 "${GTS_DB}" "VACUUM INTO '${DB_BACKUP}'"; then
    log_message "Database backup created successfully"

    # Check database integrity
    log_message "Checking database integrity"
    INTEGRITY_CHECK=$(sqlite3 "${DB_BACKUP}" 'PRAGMA integrity_check')

    if [ "${INTEGRITY_CHECK}" = "ok" ]; then
        log_message "Database integrity check passed"
        # Process the database backup
        process_backup "${DB_BACKUP}"
    else
        handle_error "Database integrity check failed: ${INTEGRITY_CHECK}"
    fi
else
    handle_error "Database backup failed"
fi

# Initialize rsync arguments for media backup
#   -av             Archive mode and verbose
#   --relative      Preserve path structure
#   --files-from=-  Read file list from stdin
RSYNC_ARGS="-av --relative --files-from=-"

# Add --link-dest only if latest backup exists
if [ -d "${LATEST_LINK}" ]; then
    RSYNC_ARGS+=" --link-dest=${LATEST_LINK}"
fi

# Perform the media backup
log_message "Starting media backup to ${BACKUP_DIR}"

# Create a temporary file for the source list
TMPFILE=$(mktemp)

# Get the list of files and prepare them for rsync
for MEDIA in attachment emoji; do
    gts_admin "media" "list-${MEDIA}s" "--local-only" | grep ${MEDIA} | while read -r file; do
        # Remove leading slash for rsync --relative
        echo ".${file}" >> "${TMPFILE}"
    done
done

# Check if we have files to backup
if [ -s "${TMPFILE}" ]; then
    # Perform the rsync backup
    # $RSYNC_ARGS is a string and should not be quoted
    # shellcheck disable=SC2086
    if rsync ${RSYNC_ARGS} / "${BACKUP_DIR}" < "${TMPFILE}"; then
        log_message "Media backup completed successfully"

        # Calculate and log space usage
        BACKUP_SIZE=$(du -sh "${BACKUP_DIR}" | cut -f 1)
        log_message "Total backup size: ${BACKUP_SIZE}"

        # Get the expected backup extension
        BACKUP_EXT=$(get_backup_extension)

        # Verify the backup contents
        log_message "Verifying backup contents"
        if [ -f "${DB_BACKUP}.${BACKUP_EXT}" ]; then
            log_message "✓ Database backup present and processed"
        else
            handle_error "Database backup missing or not processed"
        fi

        if [ -f "${EXPORT_BACKUP}.${BACKUP_EXT}" ]; then
            log_message "✓ GoToSocial export present and processed"
        else
            handle_error "GoToSocial export missing or not processed"
        fi

        # Count media files
        MEDIA_COUNT=$(find "${BACKUP_DIR}" -type f ! -name "*.${BACKUP_EXT}" | wc -l)
        log_message "✓ Files backed up: ${MEDIA_COUNT}"

        # Only proceed with cleanup and latest link update if verification passed
        if [ -f "${DB_BACKUP}.${BACKUP_EXT}" ] && [ -f "${EXPORT_BACKUP}.${BACKUP_EXT}" ] && [ "${MEDIA_COUNT}" -gt 0 ]; then
            log_message "Backup verification completed successfully"

            # Update the 'latest' symlink
            rm -f "${LATEST_LINK}"
            ln -s "${BACKUP_DIR}" "${LATEST_LINK}"

            # Clean up old backups
            log_message "Looking for backups older than ${RETENTION_DAYS} days (excluding today's backups)"
            while read -r backup_dir; do
                backup_date=$(basename "${backup_dir}" | cut -d'_' -f 1)
                if [ "${backup_date}" != "${TODAY}" ]; then
                    log_message "Removing old backup: ${backup_dir}"
                    rm -rf "${backup_dir}"
                else
                    log_message "Keeping today's backup: ${backup_dir}"
                fi
            done < <(find "${BACKUP_ROOT}" -maxdepth 1 -type d -mtime "+${RETENTION_DAYS}" -name "20*")
            log_message "Retention policy: keeping backups for ${RETENTION_DAYS} days"
        else
            handle_error "Backup verification failed"
        fi
    else
        handle_error "Media backup failed"
    fi
else
    log_message "No media files found to backup"
fi

log_message "Backup process completed"
