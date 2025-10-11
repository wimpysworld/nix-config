#!/usr/bin/env bash

# Default values
BACKUP_ROOT="/mnt/data/backups/sqlite"
CONFIG_FILE="/etc/backup-sqlite.conf"
NTFY_SERVER=""
NTFY_TOPIC=""
PASSPHRASE=""
RETENTION_DAYS=28

function usage() {
    echo "Usage: $0 [-c config_file] db_path..."
    echo "Options:"
    echo "  -c: Config file (default: ${CONFIG_FILE})"
    exit 1
}

# Function to send notifications via ntfy
function send_ntfy() {
    local error_message="${1}"
    if [ -n "${NTFY_SERVER}" ] && [ -n "${NTFY_TOPIC}" ]; then
        curl -d "${error_message}" "https://${NTFY_SERVER}/${NTFY_TOPIC}"
    fi
}

# Function to perform backup and integrity check
function backup_database() {
    local db_path="${1}"
    local db_name=""
    db_name=$(basename "${db_path}")
    local backup_subdir="$BACKUP_DIR/${db_name}_backup"
    local backup_file="${backup_subdir}/${db_name}"
    local encrypted_file="${backup_file}.enc"

    echo "Processing ${db_path}..."

    # Create backup directory
    mkdir -p "${backup_subdir}"

    # Create backup with VACUUM INTO
    if ! sqlite3 "${db_path}" "VACUUM INTO '${backup_file}';"; then
        send_ntfy "${db_name}: VACUUM INTO failed"
        return 1
    fi

    # Check backup integrity
    if ! sqlite3 "${backup_file}" "PRAGMA integrity_check;" > "${backup_subdir}/integrity_check.log"; then
        send_ntfy "${db_name}: Integrity check failed"
        return 1
    fi

    # Compress and encrypt the backup
    # Decrypt with:
    #   openssl enc -d -aes-256-cbc -pbkdf2 -salt -pass:<passphrase> -in backup.db.enc | gunzip > backup.db
    if [ -n "${PASSPHRASE}" ]; then
        if ! gzip -c "${backup_file}" | openssl enc -aes-256-cbc -pbkdf2 -salt -pass "pass:${PASSPHRASE}" > "${encrypted_file}"; then
            send_ntfy "${db_name}: Encryption failed"
            return 1
        fi
        # Remove unencrypted backup
        rm "${backup_file}"
    else
        if ! gzip -f "${backup_file}"; then
            send_ntfy "${db_name}: Compression failed"
            return 1
        fi
    fi

    echo "Successfully backed up and encrypted ${db_path}"
    return 0
}

# Parse arguments
while getopts "c:" opt; do
    case $opt in
        c) CONFIG_FILE="$OPTARG";;
        *) usage ;;
    esac
done
shift $((OPTIND-1))

# Validate required arguments
if [ $# -eq 0 ]; then
    send_ntfy "No database files specified"
    usage
fi

# Source config
if [ -f "${CONFIG_FILE}" ]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
fi

# Create timestamped backup directory
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_ROOT}/${BACKUP_DATE}"
mkdir -p "${BACKUP_DIR}"

# Process each database
for db in "$@"; do
    if [ ! -f "${db}" ]; then
        send_ntfy "$(basename "${db}") Database file not found"
        continue
    fi
    backup_database "${db}"
done

# Clean up old backups
find "${BACKUP_ROOT}" -type d -mtime "+${RETENTION_DAYS}" -exec rm -rf {} \;

echo "Backup completed: ${BACKUP_DIR}"
