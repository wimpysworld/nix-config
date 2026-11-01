#!/usr/bin/env bash
# Operator-run provisioning. Run outside Fence, not from an agent session.
set -euo pipefail
export LC_ALL=C GH_PROMPT_DISABLED=1 GIT_TERMINAL_PROMPT=0

if [[ $# != 0 ]]; then
    printf 'Usage: gh-clone-orgs (no arguments)\n' >&2
    exit 2
fi
for tool in gh gh-api-safe git jq; do
    command -v "$tool" >/dev/null || { printf 'Missing command: %s\n' "$tool" >&2; exit 1; }
done
# Do not let a caller's Git environment redirect checkout inspection.
if [[ -n ${GIT_DIR:-}${GIT_WORK_TREE:-}${GIT_COMMON_DIR:-}${GIT_INDEX_FILE:-} ]]; then
    printf 'Unset Git directory overrides before running.\n' >&2
    exit 1
fi
home=$(cd "$HOME" && pwd -P)
root=$home/Development
status=0
fail() { printf 'SKIP %s: %s\n' "$1" "$2" >&2; status=1; }
# Check only directories that this command owns. Never follow their symlinks.
directory() {
    [[ ! -L $1 ]] && { [[ -d $1 ]] || { [[ ! -e $1 ]] && mkdir "$1"; }; }
}
if ! directory "$root"; then
    fail Development 'not a plain directory'
    exit 1
fi
shopt -s nullglob dotglob nocasematch
for org in wimpysworld oval-tutu linuxmatters quickemu-project noughtylinux; do
    # Capture every page before taking action. Failed or malformed enumeration
    # must not look like an empty organisation or a usable partial inventory.
    if ! pages=$(gh-api-safe "orgs/$org/repos?per_page=100&type=all" --paginate 2>/dev/null); then
        fail "$org" 'repository enumeration failed'
        continue
    fi
    if ! repos=$(jq -rs --arg org "$org" '
        def component: type == "string" and test("^[A-Za-z0-9_.-]+$")
            and . != "." and . != ".." and (startswith("-") | not);
        if length > 0 and all(.[]; type == "array") and
            all(.[][]; type == "object" and
                (.name | component) and (.owner.login | component) and
                ((.owner.login | ascii_downcase) == $org) and
                (.full_name == (.owner.login + "/" + .name)) and
                (.archived | type == "boolean"))
        then [ .[][] | select(.archived == false) |
            {owner: .owner.login, name: .name,
             dest: (if (.name | startswith(".")) then ("_" + .name[1:]) else .name end)} ] |
            group_by((.owner + "/" + .dest) | ascii_downcase) |
            map(.[] + {collision: (length > 1)}) |
            .[] | [.owner, .name, .dest, .collision] | @tsv
        else error("invalid repository enumeration") end
    ' <<< "$pages" 2>/dev/null); then
        fail "$org" 'invalid repository enumeration'
        continue
    fi
    [[ -n $repos ]] || { printf 'EMPTY %s: no nonarchived repositories\n' "$org"; continue; }
    while IFS=$'\t' read -r owner name basename collision; do
        identity=$owner/$name
        dest=$root/$owner/$basename
        if [[ $collision == true || $name == .git || $basename == .git || $basename == _worktrees ]]; then
            fail "$identity" 'destination collision or reserved directory'
            continue
        fi
        # Reject case aliases even on case-sensitive disks, for portable layouts.
        conflict=false
        for entry in "$root"/*; do
            if [[ ${entry##*/} == "$owner" ]] && ! test "${entry##*/}" = "$owner"; then conflict=true; fi
        done
        if $conflict || ! directory "$root/$owner"; then
            fail "$identity" 'owner directory collision, symlink or non-directory'
            continue
        fi
        for entry in "$root/$owner"/*; do
            if [[ ${entry##*/} == "$basename" ]] && ! test "${entry##*/}" = "$basename"; then conflict=true; fi
        done
        if $conflict || [[ -L $dest ]]; then
            fail "$identity" 'destination collision or symlink'
            continue
        fi
        if [[ ! -e $dest ]]; then
            if git -c credential.https://github.com.helper= \
                -c 'credential.https://github.com.helper=!gh auth git-credential' \
                clone -- "https://github.com/$identity.git" "$dest" >/dev/null 2>&1; then
                printf 'CLONED %s\n' "$identity"
            else
                fail "$identity" 'clone failed (inspect any partial destination manually)'
            fi
            continue
        fi
        if [[ ! -d $dest/.git || -L $dest/.git ]] ||
            ! top=$(git -C "$dest" rev-parse --show-toplevel 2>/dev/null) ||
            [[ $top != "$dest" ]]; then
            fail "$identity" 'not a plain repository rooted at the destination'
            continue
        fi
        if ! url=$(git -C "$dest" remote get-url --all origin 2>/dev/null); then
            fail "$identity" 'origin missing'
            continue
        fi
        # Accept only standard GitHub HTTPS and SSH identities, never print URLs.
        ssh_origin=false
        case "$url" in
            https://github.com/*) remote=${url#https://github.com/} ;;
            git@github.com:*) remote=${url#git@github.com:}; ssh_origin=true ;;
            ssh://git@github.com/*) remote=${url#ssh://git@github.com/}; ssh_origin=true ;;
            *) remote= ;;
        esac
        remote=${remote%.git}
        if [[ $remote != "$identity" ]]; then
            fail "$identity" 'origin identity mismatch or unsupported URL'
            continue
        fi
        if $ssh_origin; then
            if ! git -C "$dest" remote set-url origin "https://github.com/$identity.git" >/dev/null 2>&1; then
                fail "$identity" 'origin HTTPS migration failed'
                continue
            fi
        fi
        # Empty refmap ignores configured fetch destinations. Explicit refs only
        # update origin tracking branches, not local branches or tags.
        if git -C "$dest" -c maintenance.auto=false \
            -c credential.https://github.com.helper= \
            -c 'credential.https://github.com.helper=!gh auth git-credential' \
            fetch --no-prune --no-prune-tags \
            --no-tags --no-recurse-submodules --refmap= origin \
            '+refs/heads/*:refs/remotes/origin/*' >/dev/null 2>&1; then
            printf 'FETCHED %s\n' "$identity"
        else
            fail "$identity" 'fetch failed'
        fi
    done <<< "$repos"
done
exit "$status"
