#!/usr/bin/env bash

set -e
set -u
set -o pipefail

REPOS=(
    "wolfi-dev/os"
    "chainguard-dev/enterprise-packages"
    "chainguard-dev/extra-packages"
    "chainguard-dev/package-version-metadata"
    "wolfi-dev/advisories"
    "chainguard-dev/enterprise-advisories"
    "chainguard-dev/extra-advisories"
    "chainguard-images/images-private"
    "chainguard-dev/melange"
    "chainguard-dev/apko"
    "chainguard-dev/mono"
    "sigstore/cosign"
    "philroche/wolfi-package-status"
    "wolfi-dev/wolfictl"
    "chainguard-dev/malcontent"
    "chainguard-dev/tw"
    "chainguard-dev/image-fulfillment-sandbox"
)

BASE_DIR="${HOME}/Development"
GITHUB_TOKEN=""
echo "Checking for GitHub CLI authentication..."
echo "󰈷 the "
ssh -T github.com || true

# shellcheck disable=SC2155
export GITHUB_TOKEN=$(gh auth token)
echo "${GITHUB_TOKEN}"

if [ -z "${GITHUB_TOKEN}" ]; then
    echo "GITHUB_TOKEN is not set. Please authenticate with GitHub CLI or set the token manually."
    exit 1
fi

echo "Starting repository processing..."
echo "Base directory for clones: ${BASE_DIR}"
echo ""

for item in "${REPOS[@]}"; do
    repo_full_path_for_gh=""
    org=""
    repo_name=""

    # Standard format: org/repo
    if [[ "${item}" != *"/"* ]]; then
        echo "Skipping invalid repository entry (missing '/'): ${item}"
        echo "----------------------------------------"
        echo ""
        continue
    fi
    IFS='/' read -r org repo_name <<< "${item}"
    if [[ -z "${org}" || -z "${repo_name}" ]]; then
        echo "Skipping invalid repository entry (empty org or repo_name from '${item}'): ${item}"
        echo "----------------------------------------"
        echo ""
        continue
    fi
    repo_full_path_for_gh="${item}"

    org_dir="${BASE_DIR}/${org}"
    target_repo_dir="${org_dir}/${repo_name}"

    echo "----------------------------------------"
    echo "Processing ${org}/${repo_name}"
    echo "Target directory: ${target_repo_dir}"

    # Create organization directory if it doesn't exist
    if [ ! -d "${org_dir}" ]; then
        echo "Organization directory ${org_dir} does not exist. Creating..."
        if ! mkdir -p "${org_dir}"; then
            echo "Failed to create directory ${org_dir}. Skipping ${org}/${repo_name}."
            echo "----------------------------------------"
            echo ""
            continue
        fi
        echo "Created directory ${org_dir}"
    fi

    # Check if repository directory exists
    if [ -d "${target_repo_dir}" ]; then
        echo "Repository ${target_repo_dir} already exists."
        echo "Pulling latest changes and updating submodules..."
        (
            cd "${target_repo_dir}" && \
            echo "Current directory: $(pwd)" && \
            echo "Running: git pull --ff-only" && \
            git pull --ff-only && \
            echo "Running: git submodule update --init --recursive" && \
            git submodule update --init --recursive
        )
        # shellcheck disable=SC2181
        if [ $? -ne 0 ]; then
            echo "Error updating ${target_repo_dir}. Please check the output above and the directory itself."
        else
            echo "Successfully updated ${target_repo_dir}."
        fi
    else
        echo "Repository ${target_repo_dir} does not exist."
        echo "Cloning https://github.com/${repo_full_path_for_gh}.git into ${org_dir} (will create ${repo_name} subdirectory)..."
        (
            cd "${org_dir}" && \
            echo "Current directory: $(pwd)" && \
            echo "Running: git clone https://github.com/${repo_full_path_for_gh}.git ${repo_name} --recurse-submodules" && \
            git clone "https://github.com/${repo_full_path_for_gh}.git" "${repo_name}" --recurse-submodules
        )
        # shellcheck disable=SC2181
        if [ $? -ne 0 ]; then
            echo "Error cloning ${repo_full_path_for_gh}. Please check the output above and ensure 'git' is configured."
        else
            echo "Successfully cloned ${repo_full_path_for_gh} into ${target_repo_dir}."
        fi
    fi
    echo "Finished processing ${org}/${repo_name}."
    echo "----------------------------------------"
    echo ""
done

echo "All repositories processed."
