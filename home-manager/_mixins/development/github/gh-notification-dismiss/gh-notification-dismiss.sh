#!/usr/bin/env bash

# gh-notification-dismiss: Fence-friendly helper for marking a GitHub
# notification thread as done or read.

readonly EX_POLICY=64

die() {
	printf 'gh-notification-dismiss: %s\n' "$*" >&2
	exit "${EX_POLICY}"
}

usage() {
	cat <<'EOF'
gh-notification-dismiss: mark a GitHub notification thread as done or read.

USAGE
    gh-notification-dismiss [--read] <thread-id>
    gh-notification-dismiss --help

EXAMPLES
    gh-notification-dismiss 123456789
    gh-notification-dismiss --read 123456789

POLICY
    The <thread-id> argument must match ^[1-9][0-9]*$ (strictly positive
    decimal digits, with no slashes, dots, or query strings). Any other
    thread identifier or extra flag is rejected with exit 64.

    By default, gh-notification-dismiss calls:
      DELETE notifications/threads/<thread-id>
    which marks the notification thread as done.

    With --read, gh-notification-dismiss calls:
      PATCH notifications/threads/<thread-id>
    which marks the notification thread as read.
EOF
}

if [[ $# -eq 1 && ($1 == "--help" || $1 == "-h") ]]; then
	usage
	exit 0
fi

mode="done"
method="DELETE"
thread_id=""

if [[ $# -eq 1 ]]; then
	thread_id="$1"
elif [[ $# -eq 2 && $1 == "--read" ]]; then
	mode="read"
	method="PATCH"
	thread_id="$2"
else
	die "expected usage: gh-notification-dismiss [--read] <thread-id> (try: gh-notification-dismiss --help)"
fi

if [[ ${thread_id} == -* ]]; then
	die "flag-like argument '${thread_id}' is not permitted in <thread-id> position"
fi

readonly THREAD_ID_PATTERN='^[1-9][0-9]*$'
if [[ ! ${thread_id} =~ ${THREAD_ID_PATTERN} ]]; then
	die "thread-id '${thread_id}' must match ^[1-9][0-9]*$"
fi

: "${GH_NOTIFICATION_DISMISS_GH_BIN:=gh}"
readonly GH_NOTIFICATION_DISMISS_GH_BIN
export GH_PROMPT_DISABLED=true
export GH_TELEMETRY=false

set +e
"${GH_NOTIFICATION_DISMISS_GH_BIN}" api --method "${method}" "notifications/threads/${thread_id}" </dev/null
gh_status=$?
set -e
if [[ ${gh_status} -ne 0 ]]; then
	printf 'gh-notification-dismiss: gh exited %s while marking thread %s as %s.\n' "${gh_status}" "${thread_id}" "${mode}" >&2
	exit "${gh_status}"
fi

printf 'gh-notification-dismiss: marked thread %s as %s.\n' "${thread_id}" "${mode}"
