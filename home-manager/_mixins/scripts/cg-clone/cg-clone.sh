#!/usr/bin/env bash

set -e
set -u
set -o pipefail

BASE_DIR="${HOME}/Development"

if [ -e ~/.config/cg-repos ]; then
    # shellcheck disable=SC1090
    source ~/.config/cg-repos
    if [ -z "${CG_REPOS:-}" ]; then
        echo " ERROR! CG_REPOS array is not set in ${HOME}/.config/cg-repos."
        echo "         Please ensure it is defined with the format: CG_REPOS=( 'org/repo1' 'org/repo2' ... )"
        exit 1
    fi
else
    echo " ERROR! Configuration file ${HOME}/.config/cg-repos does not exist."
    echo "         Please create it with the CG_REPOS array."
    exit 1
fi

# shellcheck disable=SC2086
if [ -z "${GITHUB_TOKEN}" ]; then
    echo "󰊤 ERROR! GITHUB_TOKEN is not set."
    echo "        Please authenticate GitHub CLI: 'gh auth login'."
    exit 1
fi

echo "Starting repository processing..."
echo " Base directory for clones: ${BASE_DIR}"
echo ""

gitsign_setup() {
    target_repo_dir="$1"
    pushd "${target_repo_dir}" > /dev/null || return 1
    if [ -d .git ]; then
        git config --local commit.gpgsign true
        git config --local tag.gpgsign true
        git config --local gpg.x509.program gitsign
        git config --local gpg.format x509
        git config --local gitsign.connectorID https://accounts.google.com
    else
        echo "No Git repository found in ${BASE_DIR}. Skipping Gitsign setup."
    fi
    popd
}

for item in "${CG_REPOS[@]}"; do
    repo_full_path_for_gh=""
    org=""
    repo_name=""

    # Standard format: org/repo
    if [[ "${item}" != *"/"* ]]; then
        echo " Skipping invalid repository entry (missing '/'): ${item}"
        echo "----------------------------------------"
        echo ""
        continue
    fi
    IFS='/' read -r org repo_name <<< "${item}"
    if [[ -z "${org}" || -z "${repo_name}" ]]; then
        echo " Skipping invalid repository entry (empty org or repo_name from '${item}'): ${item}"
        echo "----------------------------------------"
        echo ""
        continue
    fi
    repo_full_path_for_gh="${item}"

    org_dir="${BASE_DIR}/${org}"
    target_repo_dir="${org_dir}/${repo_name}"

    echo "----------------------------------------"
    echo " Processing ${org}/${repo_name}"
    echo " Target directory: ${target_repo_dir}"

    # Create organization directory if it doesn't exist
    if [ ! -d "${org_dir}" ]; then
        if ! mkdir -p "${org_dir}"; then
            echo "󰷌 ERROR! Failed to create directory ${org_dir}. Skipping ${org}/${repo_name}."
            echo "----------------------------------------"
            echo ""
            continue
        fi
    fi

    # Check if repository directory exists
    if [ -d "${target_repo_dir}" ]; then
        echo "󰓂 Pulling latest changes and updating submodules..."
        (
            cd "${target_repo_dir}" && \
            echo " - git pull --ff-only" && \
            git pull --ff-only && \
            echo " - git submodule update --init --recursive" && \
            git submodule update --init --recursive
        )
        # shellcheck disable=SC2181
        if [ $? -ne 0 ]; then
            echo " ERROR! updating ${target_repo_dir}."
        else
            gitsign_setup "${target_repo_dir}"
        fi
    else
        echo " Cloning https://github.com/${repo_full_path_for_gh}.git into ${org_dir} (will create ${repo_name} subdirectory)..."
        (
            cd "${org_dir}" && \
            echo " - git clone https://github.com/${repo_full_path_for_gh}.git ${repo_name} --recurse-submodules" && \
            git clone "https://github.com/${repo_full_path_for_gh}.git" "${repo_name}" --recurse-submodules
        )
        # shellcheck disable=SC2181
        if [ $? -ne 0 ]; then
            echo " ERROR! cloning ${repo_full_path_for_gh}."
        else
            gitsign_setup "${org_dir}/${repo_name}"
        fi
    fi
    echo "Finished processing ${org}/${repo_name}."
    echo "----------------------------------------"
    echo ""
done
