#!/usr/bin/env bash
# Runs in the package check phase. Git and GitHub are mocks, never live tools.
set -euo pipefail
script=${1:?script path required}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME=$tmp/home LOG=$tmp/log DATA=$tmp/data MODE=ok
mkdir -p "$HOME" "$tmp/bin"
export PATH=$tmp/bin:$PATH
cat > "$tmp/bin/gh-api-safe" <<'MOCK'
#!/usr/bin/env bash
set -eu
[[ $2 == --paginate ]] || exit 90
printf '%s\n' "$1" >> "$LOG.api"
case $1 in
    orgs/wimpysworld/*) cat "$DATA"; [[ $MODE != api-fail ]] ;;
    *) printf '[]\n' ;;
esac
MOCK
cat > "$tmp/bin/git" <<'MOCK'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$LOG"
if [[ $1 == clone ]]; then [[ $MODE != clone-fail ]]; exit; fi
[[ $1 == -C ]] || exit 91
dest=$2
shift 2
case $1 in
    rev-parse) [[ $MODE != bad-root ]] && printf '%s\n' "$dest" || printf '/wrong\n' ;;
    remote)
        case $MODE in
            mismatch) printf 'https://secret@github.com/other/repo.git\n' ;;
            missing) exit 1 ;;
            *) printf 'git@github.com:WimpysWorld/project.git\n' ;;
        esac ;;
    -c)
        [[ "$*" == '-c maintenance.auto=false fetch --no-prune --no-prune-tags --no-tags --no-recurse-submodules --refmap= origin +refs/heads/*:refs/remotes/origin/*' ]] || exit 92
        [[ $MODE != fetch-fail ]] ;;
    *) exit 93 ;;
esac
MOCK
chmod +x "$tmp/bin/gh-api-safe" "$tmp/bin/git"
fixture() {
    jq -n --arg name "$1" '[{name:$name, owner:{login:"WimpysWorld"}, full_name:("WimpysWorld/"+$name), archived:false, fork:true}]' > "$DATA"
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
grep -q 'https://github.com/WimpysWorld/.github.git .*Development/WimpysWorld/_github' "$LOG"
[[ $(wc -l < "$LOG.api") == 5 ]]
# Separate JSON pages, ordinary forks included and archived entries excluded.
fixture project
printf '\n[{"name":"old","owner":{"login":"WimpysWorld"},"full_name":"WimpysWorld/old","archived":true}]\n' >> "$DATA"
run 0
[[ $(grep -c '^clone ' "$LOG") == 1 ]]
mkdir -p "$HOME/Development/WimpysWorld/project/.git" "$HOME/Development/WimpysWorld/project/.github"
printf keep > "$HOME/Development/WimpysWorld/project/.github/workflow.yml"
run 0
grep -q 'fetch --no-prune' "$LOG"
[[ $(< "$HOME/Development/WimpysWorld/project/.github/workflow.yml") == keep ]]
for MODE in mismatch missing bad-root; do
    export MODE
    run 1
    if grep -q ' fetch ' "$LOG"; then exit 1; fi
done
MODE=fetch-fail run 1
MODE=ok
fixture absent
MODE=clone-fail run 1
MODE=api-fail run 1
[[ ! -s $LOG ]]
MODE=ok
for data in '' '{}' '[{"archived":false}]' '[{"name":"../escape","owner":{"login":"WimpysWorld"},"full_name":"WimpysWorld/../escape","archived":false}]'; do
    printf '%s' "$data" > "$DATA"
    run 1
    [[ ! -s $LOG ]]
done
printf '[]\n[]\n' > "$DATA"
run 0
[[ ! -s $LOG ]]
fixture .github
jq '.[0].name="_github" | .[0].full_name="WimpysWorld/_github"' "$DATA" >> "$tmp/page"
cat "$tmp/page" >> "$DATA"
run 1
[[ ! -s $LOG ]]
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
grep -q '^clone .*zz-valid' "$LOG"
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
