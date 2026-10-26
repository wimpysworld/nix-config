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
# one is set. Each step sends its errors to stderr, which this script shows
# when the step fails. The remote shell expands the variables, not this one.
# The token is read once into an unexported variable, and the printf builtin
# feeds it to gh, so it never appears in argv or a child environment. A first
# login can fail after it writes hosts.yml, so a failed login is tried once
# more. When the retry succeeds, the first error follows the retry marker on
# stderr, so that this script can show it as a warning.
# shellcheck disable=SC2016
remote_script='
PATH="$HOME/.nix-profile/bin:$HOME/.local/state/nix/profile/bin:/etc/profiles/per-user/${USER:-}/bin:/run/current-system/sw/bin:$PATH"
export PATH
unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN
token=$(cat)
retried=
login() {
  printf "%s" "$token" | gh auth login --with-token --hostname github.com --insecure-storage 2>&1 >/dev/null
}
command -v gh >/dev/null 2>&1 || exit 10
command -v gh-credential-sync >/dev/null 2>&1 || exit 11
if ! first=$(login); then
  sleep 2
  if ! second=$(login); then
    { echo "First attempt:"; printf "%s" "$first"; echo; echo "Second attempt:"; printf "%s" "$second"; echo; } >&2
    exit 12
  fi
  retried=1
fi
gh auth status --hostname github.com >/dev/null || exit 13
gh-credential-sync >/dev/null || exit 14
if [ -n "$retried" ]; then
  echo "gh-token-push-retry" >&2
  printf "%s" "$first" >&2
fi
'
remote_command="sh -c '${remote_script}'"

# gh does not echo a token, but the remote output is redacted before it is
# shown: first the token itself, then anything with a GitHub token prefix.
show_error() {
  local error=${1//"$token"/[redacted]}
  printf '%s\n' "$error" |
    sed -E -e 's/(gh[oprsu]_|github_pat_)[A-Za-z0-9_]+/[redacted]/g' -e 's/^/    /'
}

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
    if [[ $ssh_error == *gh-token-push-retry* ]]; then
      first_error=${ssh_error##*gh-token-push-retry}
      first_error=${first_error#$'\n'}
      printf '  warning: the first gh auth login failed, the retry succeeded.\n'
      show_error "${first_error:-(no error output)}"
    fi
  else
    printf '%s: failed (%s)\n' "$host" "$reason"
    if [[ $status != 255 && -n $ssh_error ]]; then
      show_error "$ssh_error"
    fi
    failed=1
  fi
done
exit "$failed"
