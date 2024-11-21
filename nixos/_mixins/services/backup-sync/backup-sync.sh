#!/usr/bin/env bash

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root" >&2
    exit 1
fi

# Configuration
LOCAL_BACKUP="/mnt/data/backup/"
REMOTE_HOSTS=(
    "revan:/mnt/snapshot/backup-malak/"
    "phasma:/mnt/snapshot/backup-malak/"
    "vader:/mnt/snapshot/backup-malak/"
)
LOG_DIR="/var/log/backup-sync"
MAX_LOG_LINES=4096

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Function to send notifications via ntfy
function send_ntfy() {
    local error_message="${1}"

    if [ -e "/etc/backup-sync.env" ]; then
        # shellcheck disable=1091
        source "/etc/backup-sync.env"
        if [ -n "${NTFY_SERVER}" ] && [ -n "${NTFY_TOPIC}" ]; then
            curl -d "${error_message}" "https://${NTFY_SERVER}/${NTFY_TOPIC}"
        fi
    fi
}

# Function to truncate log file
function truncate_log() {
    local log_file="${1}"
    if [ -f "${log_file}" ]; then
        tail -n ${MAX_LOG_LINES} "${log_file}" > "${log_file}.tmp"
        mv "${log_file}.tmp" "${log_file}"
    fi
}

# Function to log messages
function log_message() {
    local message="${1}"
    local is_error="${2:-false}"
    local log_file="${LOG_DIR}/backup-sync.log"

    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${message}" >> "${log_file}"
    truncate_log "${log_file}"

    if [ "${is_error}" = true ]; then
        send_ntfy "${message}"
    fi
}

# Function to extract hostname from remote path
function get_hostname() {
    local remote_path="${1}"
    echo "${remote_path}" | cut -d':' -f1
}

# Function to extract remote path from full remote string
function get_remote_path() {
    local remote_string="${1}"
    echo "${remote_string}" | cut -d':' -f2
}

# Function to check backup directory status
function check_backup_directory() {
    local dir="${1}"

    # Remove trailing slash for consistent testing
    dir="${dir%/}"

    # Check if the directory exists
    if [ ! -e "${dir}" ]; then
        log_message "ERROR: Backup directory '${dir}' does not exist" true
        return 1
    fi

    # Check if it's actually a directory
    if [ ! -d "${dir}" ]; then
        log_message "ERROR: '${dir}' exists but is not a directory" true
        return 1
    fi

    # Check if we have read access
    if [ ! -r "${dir}" ]; then
        log_message "ERROR: No read permission for backup directory '${dir}'" true
        return 1
    fi

    # Check if directory is mounted (if it's a mount point)
    if mountpoint -q "${dir}" && ! findmnt "${dir}" >/dev/null; then
        log_message "ERROR: Backup directory '${dir}' is a mount point but nothing is mounted" true
        return 1
    fi

    # Check if directory is empty (including hidden files)
    if [ -z "$(find "${dir}" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
        log_message "ERROR: Backup directory '${dir}' is empty" true
        return 1
    fi

    return 0
}

# Check backup directory status before proceeding
if ! check_backup_directory "${LOCAL_BACKUP}"; then
    exit 1
fi

# Perform sync to each remote host
for remote in "${REMOTE_HOSTS[@]}"; do
    hostname=$(get_hostname "${remote}")
    remote_path=$(get_remote_path "${remote}")

    log_message "Starting sync to ${hostname}"

    rsync -av --human-readable --progress --delete \
        --hard-links --partial --stats \
        "${LOCAL_BACKUP}" "${remote}" 2>&1 | \
        tee -a "${LOG_DIR}/rsync-${hostname}.log"

    if [ "${PIPESTATUS[0]}" -eq 0 ]; then
        log_message "Successfully completed sync to ${hostname}"
    else
        log_message "ERROR: Sync failed for ${hostname}" true
    fi

    # Truncate rsync log
    truncate_log "${LOG_DIR}/rsync-${hostname}.log"
done
