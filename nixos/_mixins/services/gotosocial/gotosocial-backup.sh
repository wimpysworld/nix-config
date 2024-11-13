#!/usr/bin/env bash
# Backup script for GoToSocial
# - exports data, backs up the SQLite database, and media files
# - https://docs.gotosocial.org/en/latest/admin/backup_and_restore/
# - https://litestream.io/alternatives/cron/

set +e          # Disable errexit
set +u          # Disable nounset
set +o pipefail # Disable pipefail

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root" >&2
    exit 1
fi

# Configuration
BACKUP_ROOT="/mnt/data/backup/gotosocial"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CURRENT_DATE=$(date +%Y%m%d)
LATEST_LINK="$BACKUP_ROOT/latest"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
LOGFILE="$BACKUP_ROOT/backup.log"
DB_SOURCE="/var/lib/gotosocial/database.sqlite"
DB_BACKUP="$BACKUP_DIR/database.sqlite"
EXPORT_TEMP="/tmp/gotosocial_export_$TIMESTAMP.json"
EXPORT_BACKUP="$BACKUP_DIR/export.json"
# Default retention period in days
RETENTION_DAYS=28
# Default config path
GTS_CONFIG_PATH="/etc/gotosocial/config.yaml"

# Allow override of retention period via environment variable
if [ -n "${BACKUP_RETENTION_DAYS}" ]; then
    if [[ "${BACKUP_RETENTION_DAYS}" =~ ^[0-9]+$ ]]; then
        RETENTION_DAYS="${BACKUP_RETENTION_DAYS}"
        log_message "Using custom retention period of ${RETENTION_DAYS} days"
    else
        log_message "Warning: Invalid BACKUP_RETENTION_DAYS value. Using default of ${RETENTION_DAYS} days"
    fi
fi

# Function to execute gotosocial admin
# NixOS installs the gotosocial-admin helper, so use it if available
function gts_admin() {
    local command="${1}"
    # Remove the first argument, leaving the rest in $@
    shift
    if [ -x /run/current-system/sw/bin/gotosocial-admin ]; then
        /run/current-system/sw/bin/gotosocial-admin "$command" "${@}"
    else
        gotosocial --config-path "${GTS_CONFIG_PATH}" admin "${command}" "${@}"
    fi
}

# Function to log messages
function log_message() {
    echo "$(date '+%Y/%m/%d %H:%M:%S') ${1}" | tee -a "${LOGFILE}"
}

# Function to handle errors
function handle_error() {
    log_message "ERROR: ${1}" | tee -a "${LOGFILE}"
    exit 1
}

# Function to clean up temporary files
function cleanup() {
    [ -f "${TMPFILE}" ] && rm -f "${TMPFILE}"
    [ -f "${EXPORT_TEMP}" ] && rm -f "${EXPORT_TEMP}"
    log_message "Cleanup completed"
}
# Set trap for cleanup on script exit
trap cleanup EXIT

# Check if running under sudo and warn about potential environment issues
if [ -n "${SUDO_USER}" ]; then
    log_message "Warning: Script is running via sudo. Environment variables from the user environment may not be preserved."
fi

# Check if we're using gotosocial-admin or gotosocial
if [ -x /run/current-system/sw/bin/gotosocial-admin ]; then
    log_message "Using gotosocial-admin"
elif command -v gotosocial >/dev/null 2>&1; then
    log_message "Using gotosocial with ${GTS_CONFIG_PATH}"
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
if [ ! -r "${DB_SOURCE}" ]; then
    handle_error "Database file ${DB_SOURCE} does not exist or is not readable"
fi

# Export GoToSocial data
log_message "Starting GoToSocial export"
if gts_admin "export" "--path" "${EXPORT_TEMP}"; then
    log_message "GoToSocial export completed successfully"

    # Move export file to backup directory
    if mv "${EXPORT_TEMP}" "${EXPORT_BACKUP}"; then
        log_message "Export file moved to backup directory"

        # Compress the export file
        if gzip -f "${EXPORT_BACKUP}"; then
            log_message "Export file compressed successfully"
        else
            handle_error "Failed to compress export file"
        fi
    else
        handle_error "Failed to move export file to backup directory"
    fi
else
    handle_error "GoToSocial export failed"
fi

# Backup SQLite database
log_message "Starting database backup"

# Create database backup with VACUUM
if sqlite3 "${DB_SOURCE}" "VACUUM INTO '${DB_BACKUP}'"; then
    log_message "Database backup created successfully"

    # Check database integrity
    log_message "Checking database integrity"
    INTEGRITY_CHECK=$(sqlite3 "${DB_BACKUP}" 'PRAGMA integrity_check')

    if [ "${INTEGRITY_CHECK}" = "ok" ]; then
        log_message "Database integrity check passed"

        # Compress the database backup
        log_message "Compressing database backup"
        if gzip -f "${DB_BACKUP}"; then
            log_message "Database compressed successfully"
        else
            handle_error "Failed to compress database backup"
        fi
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

        # Verify the backup contents before cleaning up old backups
        log_message "Verifying backup contents"
        if [ -f "${DB_BACKUP}.gz" ]; then
            log_message "✓ Database backup present and compressed"
        else
            handle_error "Database backup missing or not compressed"
        fi

        if [ -f "${EXPORT_BACKUP}.gz" ]; then
            log_message "✓ GoToSocial export present and compressed"
        else
            handle_error "GoToSocial export missing or not compressed"
        fi

        # Count all files excluding the database backup and its compressed version
        MEDIA_COUNT=$(find "${BACKUP_DIR}" -type f ! -name "$(basename "${DB_BACKUP}")" ! -name "$(basename "${DB_BACKUP}.gz")" ! -name "$(basename "${EXPORT_BACKUP}")" ! -name "$(basename "${EXPORT_BACKUP}.gz")" | wc -l)
        log_message "✓ Files backed up: ${MEDIA_COUNT}"

        # Only proceed with cleanup and latest link update if verification passed
        if [ -f "${DB_BACKUP}.gz" ] && [ -f "${EXPORT_BACKUP}.gz" ] && [ "${MEDIA_COUNT}" -gt 0 ]; then
            log_message "Backup verification completed successfully"

            # Update the 'latest' symlink
            rm -f "${LATEST_LINK}"
            ln -s "${BACKUP_DIR}" "${LATEST_LINK}"

            # Clean up old backups
            log_message "Looking for backups older than ${RETENTION_DAYS} days (excluding today's backups)"
            while read -r backup_dir; do
                backup_date=$(basename "${backup_dir}" | cut -d'_' -f 1)
                if [ "${backup_date}" != "${CURRENT_DATE}" ]; then
                    log_message "Removing old backup: ${backup_dir}"
                    rm -rf "${backup_dir}"
                else
                    log_message "Keeping today's backup: ${backup_dir}"
                fi
            done < <(find "${BACKUP_ROOT}" -maxdepth 1 -type d -mtime "+${RETENTION_DAYS}" -name "20*")

            # Log retention policy
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
