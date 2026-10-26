#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: gh-token-push <host> [host...]
       gh-token-push --all

Copy the local GitHub CLI token for github.com to each host over SSH, then
log in to gh on that host and run gh-credential-sync.

  --all       Target every registry server: ${GH_TOKEN_PUSH_SERVERS}
  -h, --help  Show this help.
EOF
}

fail() {
  printf 'gh-token-push: %s\n' "$*" >&2
  exit 1
}

if [[ $# == 0 ]]; then
  usage >&2
  exit 2
fi

hosts=()
case $1 in
  -h | --help)
    usage
    exit 0
    ;;
  --all)
    if [[ $# != 1 ]]; then
      usage >&2
      exit 2
    fi
    read -r -a hosts <<<"$GH_TOKEN_PUSH_SERVERS"
    ;;
  *) hosts=("$@") ;;
esac

# Check every name before any token is read, so that a typo sends nothing.
for host in "${hosts[@]}"; do
  if [[ $host == -* ]]; then
    usage >&2
    exit 2
  fi
  if ! [[ $host =~ ^([a-zA-Z0-9_][a-zA-Z0-9_.-]*@)?[a-zA-Z0-9_][a-zA-Z0-9_.-]*$ ]]; then
    printf 'gh-token-push: invalid host name: %q\n' "$host" >&2
    exit 2
  fi
done

gh auth status --hostname github.com >/dev/null 2>&1 ||
  fail 'gh is not logged in to github.com. Run: gh auth login'

# The token stays in this variable. It reaches each host only through the
# standard input of ssh, never through argv, output or a log.
token=$(gh auth token --hostname github.com 2>/dev/null) || fail 'gh auth token failed.'
[[ -n $token ]] || fail 'gh returned an empty token.'

case $token in
  gho_* | ghp_* | github_pat_*) ;;
  ghu_*) printf 'gh-token-push: warning: this is a user-to-server token, so the copy can expire.\n' >&2 ;;
  *) printf 'gh-token-push: warning: unknown token type, so the copy can expire.\n' >&2 ;;
esac

# The remote login shell can be fish, so the command runs under sh with no
# single quotes or backslashes inside. Home Manager profiles come first on
# PATH, so that gh and gh-credential-sync resolve without shell startup files.
# Inherited token variables are cleared, because gh refuses to log in while
# one is set. The remote shell expands the variables, not this one.
# shellcheck disable=SC2016
remote_script='
PATH="$HOME/.nix-profile/bin:$HOME/.local/state/nix/profile/bin:/etc/profiles/per-user/${USER:-}/bin:/run/current-system/sw/bin:$PATH"
export PATH
unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN
command -v gh >/dev/null 2>&1 || exit 10
command -v gh-credential-sync >/dev/null 2>&1 || exit 11
gh auth login --with-token --hostname github.com --insecure-storage >/dev/null 2>&1 || exit 12
gh auth status --hostname github.com >/dev/null 2>&1 || exit 13
gh-credential-sync >/dev/null 2>&1 || exit 14
'
remote_command="sh -c '${remote_script}'"

failed=0
for host in "${hosts[@]}"; do
  status=0
  ssh_error=$(printf '%s\n' "$token" |
    ssh -o BatchMode=yes -o ConnectTimeout=10 -- "$host" "$remote_command" 2>&1 >/dev/null) ||
    status=$?
  case $status in
    0) reason= ;;
    10) reason='gh not found' ;;
    11) reason='gh-credential-sync not found' ;;
    12) reason='gh auth login failed' ;;
    13) reason='gh auth status failed after login' ;;
    14) reason='gh-credential-sync failed' ;;
    255)
      ssh_error=${ssh_error##*$'\n'}
      reason="ssh: ${ssh_error:-connection failed}"
      ;;
    *) reason="exit status ${status}" ;;
  esac
  if [[ -z $reason ]]; then
    printf '%s: ok\n' "$host"
  else
    printf '%s: failed (%s)\n' "$host" "$reason"
    failed=1
  fi
done
exit "$failed"
