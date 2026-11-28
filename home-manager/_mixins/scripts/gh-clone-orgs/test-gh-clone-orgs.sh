#!/usr/bin/env bash
# Runs in the package check phase. Git and GitHub are mocks, never live tools.
set -euo pipefail
script=${1:?script path required}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME=$tmp/home LOG=$tmp/log DATA=$tmp/data MODE=ok ORIGIN_URL=https://github.com/WimpysWorld/project.git
mkdir -p "$HOME" "$tmp/bin"
export PATH=$tmp/bin:$PATH
printf '#!%s\n' "$BASH" > "$tmp/bin/gh"
cat >> "$tmp/bin/gh" <<'MOCK'
set -eu
exit 0
MOCK
printf '#!%s\n' "$BASH" > "$tmp/bin/gh-api-safe"
cat >> "$tmp/bin/gh-api-safe" <<'MOCK'
set -eu
printf '%s\n' "$1" >> "$LOG.api"
case $1 in
    orgs/wimpysworld/*)
        [[ ${2:-} == --paginate && $# == 2 ]] || exit 90
        cat "$DATA"
        [[ $MODE != api-fail ]] ;;
    orgs/*)
        [[ ${2:-} == --paginate && $# == 2 ]] || exit 90
        printf '[]\n' ;;
    repos/WimpysWorld/old-project)
        [[ $# == 1 ]] || exit 90
        [[ $MODE != rename-api-fail ]] || exit 1
        printf '{"id":42,"full_name":"WimpysWorld/project"}\n' ;;
    repos/WimpysWorld/other-project)
        [[ $# == 1 ]] || exit 90
        printf '{"id":999,"full_name":"WimpysWorld/other-project"}\n' ;;
    repos/*)
        exit 91 ;;
    *) exit 90 ;;
esac
MOCK
printf '#!%s\n' "$BASH" > "$tmp/bin/git"
cat >> "$tmp/bin/git" <<'MOCK'
set -eu
printf '%s\n' "$*" >> "$LOG"
if [[ $1 == -c ]]; then
    [[ $2 == 'credential.https://github.com.helper=' ]] || exit 94
    [[ $3 == '-c' && $4 == 'credential.https://github.com.helper=!gh auth git-credential' ]] || exit 94
    [[ $5 == clone && $6 == -- ]] || exit 94
    [[ $MODE != clone-fail ]]
    exit
fi
[[ $1 == -C ]] || exit 91
dest=$2
shift 2
case $1 in
    rev-parse)
        case ${*:2} in
            --show-toplevel) [[ $MODE != bad-root ]] && printf '%s\n' "$dest" || printf '/wrong\n' ;;
            '--abbrev-ref --symbolic-full-name @{u}')
                [[ $MODE != no-upstream ]] || exit 1
                printf 'origin/main\n' ;;
            HEAD)
                if [[ $MODE == up-to-date ]]; then
                    printf 'bbbb2222\n'
                else
                    printf 'aaaa1111\n'
                fi ;;
            origin/main) printf 'bbbb2222\n' ;;
            *) exit 96 ;;
        esac ;;
    symbolic-ref)
        [[ "$*" == 'symbolic-ref -q --short HEAD' ]] || exit 97
        [[ $MODE != detached ]] || exit 1
        printf 'main\n' ;;
    diff)
        case ${*:2} in
            --quiet) [[ $MODE != dirty-worktree ]] ;;
            '--cached --quiet') [[ $MODE != dirty-index ]] ;;
            *) exit 98 ;;
        esac ;;
    merge-base)
        [[ "$*" == 'merge-base --is-ancestor HEAD origin/main' ]] || exit 99
        [[ $MODE != diverged ]] ;;
    remote)
        if [[ $2 == set-url ]]; then
            [[ $3 == origin && $4 == https://github.com/WimpysWorld/project.git ]] || exit 95
            [[ $MODE != set-url-fail ]]
            exit
        fi
        case $MODE in
            mismatch) printf 'https://secret@github.com/other/repo.git\n' ;;
            missing) exit 1 ;;
            *) printf '%s\n' "$ORIGIN_URL" ;;
        esac ;;
    -c)
        case "$*" in
            '-c maintenance.auto=false -c credential.https://github.com.helper= -c credential.https://github.com.helper=!gh auth git-credential fetch --no-prune --no-prune-tags --no-tags --no-recurse-submodules --refmap= origin +refs/heads/*:refs/remotes/origin/*')
                [[ $MODE != fetch-fail ]] ;;
            '-c maintenance.auto=false merge --ff-only --quiet origin/main')
                [[ $MODE != merge-fail ]] ;;
            *) exit 92 ;;
        esac ;;
    *) exit 93 ;;
esac
MOCK
chmod +x "$tmp/bin/gh" "$tmp/bin/gh-api-safe" "$tmp/bin/git"
fixture() {
    jq -n --arg name "$1" '[{id:42, name:$name, owner:{login:"WimpysWorld"}, full_name:("WimpysWorld/"+$name), archived:false, fork:true}]' > "$DATA"
}
run() {
    : > "$LOG"
    : > "$LOG.api"
    code=0
    bash "$script" > "$tmp/out" 2>&1 || code=$?
    [[ $code == "$1" ]] || { cat "$tmp/out"; printf 'Expected %s, got %s\n' "$1" "$code"; exit 1; }
    if grep -q secret "$tmp/out"; then exit 1; fi
}
fixture .github
run 0
grep -q '^-c credential\.https://github\.com\.helper= -c credential\.https://github\.com\.helper=!gh auth git-credential clone -- https://github\.com/WimpysWorld/\.github\.git .*Development/WimpysWorld/_github$' "$LOG"
[[ $(wc -l < "$LOG.api") == 5 ]]
fixture .github-private
run 0
grep -q '^-c credential\.https://github\.com\.helper= -c credential\.https://github\.com\.helper=!gh auth git-credential clone -- https://github\.com/WimpysWorld/\.github-private\.git .*Development/WimpysWorld/_github-private$' "$LOG"
# Separate JSON pages, ordinary forks included and archived entries excluded.
fixture project
printf '\n[{"id":99,"name":"old","owner":{"login":"WimpysWorld"},"full_name":"WimpysWorld/old","archived":true}]\n' >> "$DATA"
run 0
[[ $(grep -c ' clone -- ' "$LOG") == 1 ]]
mkdir -p "$HOME/Development/WimpysWorld/project/.git" "$HOME/Development/WimpysWorld/project/.github"
printf keep > "$HOME/Development/WimpysWorld/project/.github/workflow.yml"
# Existing HTTPS origin fetches directly without set-url and fast-forwards when behind.
ORIGIN_URL=https://github.com/WimpysWorld/project.git run 0
if grep -q 'remote set-url' "$LOG"; then exit 1; fi
grep -q -- '-c maintenance.auto=false -c credential.https://github.com.helper= -c credential.https://github.com.helper=!gh auth git-credential fetch --no-prune' "$LOG"
grep -q -- '-c maintenance.auto=false merge --ff-only --quiet origin/main$' "$LOG"
grep -qxF 'UPDATED WimpysWorld/project' "$tmp/out"
[[ $(< "$HOME/Development/WimpysWorld/project/.github/workflow.yml") == keep ]]
# Existing SSH origin migrates to HTTPS via remote set-url before fetching.
ORIGIN_URL=git@github.com:WimpysWorld/project.git run 0
grep -q 'remote set-url origin https://github.com/WimpysWorld/project.git$' "$LOG"
grep -q -- '-c maintenance.auto=false -c credential.https://github.com.helper= -c credential.https://github.com.helper=!gh auth git-credential fetch --no-prune' "$LOG"
grep -q -- '-c maintenance.auto=false merge --ff-only --quiet origin/main$' "$LOG"
grep -qxF 'UPDATED WimpysWorld/project' "$tmp/out"
ORIGIN_URL=git@github.com:WimpysWorld/project.git MODE=set-url-fail run 1
if grep -q ' fetch ' "$LOG"; then exit 1; fi
# Verified HTTPS rename rewrites origin and proceeds to fetch and fast-forward.
ORIGIN_URL=https://github.com/WimpysWorld/old-project.git run 0
grep -qxF 'repos/WimpysWorld/old-project' "$LOG.api"
grep -q 'remote set-url origin https://github.com/WimpysWorld/project.git$' "$LOG"
grep -q -- '-c maintenance.auto=false -c credential.https://github.com.helper= -c credential.https://github.com.helper=!gh auth git-credential fetch --no-prune' "$LOG"
grep -q -- '-c maintenance.auto=false merge --ff-only --quiet origin/main$' "$LOG"
grep -qxF 'UPDATED WimpysWorld/project' "$tmp/out"
# Verified SSH rename rewrites origin to HTTPS and proceeds.
ORIGIN_URL=git@github.com:WimpysWorld/old-project.git run 0
grep -qxF 'repos/WimpysWorld/old-project' "$LOG.api"
grep -q 'remote set-url origin https://github.com/WimpysWorld/project.git$' "$LOG"
grep -q -- '-c maintenance.auto=false -c credential.https://github.com.helper= -c credential.https://github.com.helper=!gh auth git-credential fetch --no-prune' "$LOG"
grep -q -- '-c maintenance.auto=false merge --ff-only --quiet origin/main$' "$LOG"
grep -qxF 'UPDATED WimpysWorld/project' "$tmp/out"
# Unrelated repo (different id) and rename API failure reject without repointing or fetching.
ORIGIN_URL=https://github.com/WimpysWorld/other-project.git run 1
grep -qxF 'repos/WimpysWorld/other-project' "$LOG.api"
if grep -q 'remote set-url' "$LOG" || grep -q ' fetch ' "$LOG"; then exit 1; fi
ORIGIN_URL=https://github.com/WimpysWorld/old-project.git MODE=rename-api-fail run 1
grep -qxF 'repos/WimpysWorld/old-project' "$LOG.api"
if grep -q 'remote set-url' "$LOG" || grep -q ' fetch ' "$LOG"; then exit 1; fi
# Rename remote set-url failure skips fetch.
ORIGIN_URL=https://github.com/WimpysWorld/old-project.git MODE=set-url-fail run 1
grep -qxF 'repos/WimpysWorld/old-project' "$LOG.api"
grep -q 'remote set-url origin https://github.com/WimpysWorld/project.git$' "$LOG"
if grep -q ' fetch ' "$LOG"; then exit 1; fi
# Credentialed URL fails without calling gh-api-safe on it, leaking secret, repointing, or fetching.
ORIGIN_URL=https://github.com/WimpysWorld/project.git MODE=mismatch run 1
if grep -q '^repos/' "$LOG.api" || grep -q 'remote set-url' "$LOG" || grep -q ' fetch ' "$LOG"; then exit 1; fi
ORIGIN_URL=https://github.com/WimpysWorld/project.git
for MODE in missing bad-root; do
    export MODE
    run 1
    if grep -q ' fetch ' "$LOG"; then exit 1; fi
done
MODE=fetch-fail run 1
if grep -q ' merge ' "$LOG"; then exit 1; fi
# Fast-forward safety boundaries after a successful fetch.
MODE=up-to-date run 0
grep -qxF 'UP-TO-DATE WimpysWorld/project' "$tmp/out"
if grep -q ' merge ' "$LOG"; then exit 1; fi
MODE=detached run 0
grep -qxF 'FETCHED WimpysWorld/project (detached HEAD)' "$tmp/out"
if grep -q ' merge ' "$LOG"; then exit 1; fi
MODE=no-upstream run 0
grep -qxF 'FETCHED WimpysWorld/project (no upstream)' "$tmp/out"
if grep -q ' merge ' "$LOG"; then exit 1; fi
MODE=dirty-worktree run 0
grep -qxF 'FETCHED WimpysWorld/project (dirty working tree)' "$tmp/out"
if grep -q ' merge ' "$LOG"; then exit 1; fi
MODE=dirty-index run 0
grep -qxF 'FETCHED WimpysWorld/project (dirty working tree)' "$tmp/out"
if grep -q ' merge ' "$LOG"; then exit 1; fi
MODE=diverged run 0
grep -qxF 'FETCHED WimpysWorld/project (diverged)' "$tmp/out"
if grep -q ' merge ' "$LOG"; then exit 1; fi
MODE=merge-fail run 1
grep -q -- '-c maintenance.auto=false merge --ff-only --quiet origin/main$' "$LOG"
grep -qxF 'SKIP WimpysWorld/project: fast-forward failed' "$tmp/out"
MODE=ok
fixture absent
MODE=clone-fail run 1
MODE=api-fail run 1
[[ ! -s $LOG ]]
MODE=ok
for data in '' '{}' '[{"archived":false}]' '[{"id":1,"name":"../escape","owner":{"login":"WimpysWorld"},"full_name":"WimpysWorld/../escape","archived":false}]' '[{"name":"missing-id","owner":{"login":"WimpysWorld"},"full_name":"WimpysWorld/missing-id","archived":false}]' '[{"id":0,"name":"zero-id","owner":{"login":"WimpysWorld"},"full_name":"WimpysWorld/zero-id","archived":false}]' '[{"id":1.5,"name":"float-id","owner":{"login":"WimpysWorld"},"full_name":"WimpysWorld/float-id","archived":false}]' '[{"id":"42","name":"str-id","owner":{"login":"WimpysWorld"},"full_name":"WimpysWorld/str-id","archived":false}]'; do
    printf '%s' "$data" > "$DATA"
    run 1
    [[ ! -s $LOG ]]
done
printf '[]\n[]\n' > "$DATA"
run 0
[[ ! -s $LOG ]]
fixture .github
jq '.[0].name="_github" | .[0].full_name="WimpysWorld/_github"' "$DATA" > "$tmp/page"
cat "$tmp/page" >> "$DATA"
run 1
[[ ! -s $LOG ]]
fixture .github-private
jq '.[0].name="_github-private" | .[0].full_name="WimpysWorld/_github-private"' "$DATA" > "$tmp/page"
cat "$tmp/page" >> "$DATA"
run 1
[[ ! -s $LOG ]]
# Reserved destinations must never reach Git, even when populated.
for name in _worktrees _WORKTREES .worktrees .git; do
    fixture "$name"
    run 1
    [[ ! -s $LOG ]]
done
mkdir -p "$HOME/Development/WimpysWorld/_worktrees/.git"
printf keep > "$HOME/Development/WimpysWorld/_worktrees/marker"
fixture _worktrees
run 1
[[ ! -s $LOG ]]
[[ $(< "$HOME/Development/WimpysWorld/_worktrees/marker") == keep ]]
fixture blocked
ln -s "$tmp/missing" "$HOME/Development/WimpysWorld/blocked"
run 1
[[ ! -s $LOG ]]
fixture occupied
mkdir "$HOME/Development/WimpysWorld/occupied"
run 1
[[ ! -s $LOG ]]
fixture worktree
mkdir "$HOME/Development/WimpysWorld/worktree"
printf 'gitdir: elsewhere\n' > "$HOME/Development/WimpysWorld/worktree/.git"
run 1
[[ ! -s $LOG ]]
fixture PROJECT
run 1
[[ ! -s $LOG ]]
# A conflicting destination does not prevent a later valid clone.
fixture occupied
jq '.[0].name="zz-valid" | .[0].full_name="WimpysWorld/zz-valid"' "$DATA" > "$tmp/page"
cat "$tmp/page" >> "$DATA"
run 1
grep -q ' clone -- .*zz-valid' "$LOG"
# Managed owner and root symlinks never redirect actions into primary homes.
mkdir -p "$tmp/other-home/Zero"
ln -s "$tmp/other-home/Zero" "$tmp/other-home/Development"
HOME=$tmp/other-home run 1
[[ ! -s $LOG ]]
mkdir -p "$tmp/owner-home/Development" "$tmp/owner-home/Zero"
ln -s "$tmp/owner-home/Zero" "$tmp/owner-home/Development/WimpysWorld"
HOME=$tmp/owner-home run 1
[[ ! -s $LOG ]]
printf 'All provisioning boundary tests passed.\n'
