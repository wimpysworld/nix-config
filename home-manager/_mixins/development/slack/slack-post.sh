#!/usr/bin/env bash

# slack-post: post one message to Slack as the token owner.
#
# The Slack MCP server posts through Anthropic's Slack app, so Slack stamps
# every such message "Sent using @Claude" and renders the text through Block
# Kit, which leaves a custom emote such as `:wtb2:` as literal text. This
# helper posts with the user's own OAuth token and sends plain text with
# `mrkdwn`, so the message carries no app attribution and emotes resolve.
#
# Two endpoints are reachable, both fixed strings in this script:
#
#   POST https://slack.com/api/chat.postMessage
#   POST https://slack.com/api/conversations.open   (only to address a DM)
#
# Policy summary:
#   * The argument list is fixed. The target comes first, then
#     `--body-file PATH`, then an optional `--thread-ts TS`. Any other
#     argument count or order is rejected.
#   * The target is one of four forms, and each is matched against its own
#     pattern:
#       - a channel or DM ID matching ^[CDG][A-Z0-9]{7,}$
#       - a channel name matching ^#?[a-z0-9][a-z0-9._-]{0,79}$
#       - a user ID matching ^U[A-Z0-9]{7,}$, which opens the DM first
#       - a Slack message URL, which replies inside that message's thread
#     A private channel is only addressable by ID, because Slack resolves a
#     name for public channels only.
#   * A message URL must be https://<host>.slack.com/archives/<channel>/p<ts>.
#     The channel is taken from the path and the thread from the `thread_ts`
#     query parameter, falling back to the `p<digits>` timestamp in the path.
#     Both values are validated after parsing, never trusted as given.
#   * `--thread-ts` is rejected alongside a URL, because the URL already names
#     the thread and two sources could disagree.
#   * Every token that begins with `-` is rejected except the two known flags
#     in their expected positions. That refuses a body path of `-`, so stdin
#     cannot be smuggled in, and it refuses the glued `--body-file=PATH` form.
#   * Neither endpoint is ever taken from argv, so no other Slack method is
#     reachable. `conversations.open` is called with a user ID only, so it
#     cannot open anything else.
#   * The body is encoded with `jq --rawfile`, which reads the whole file as
#     one string. Quotes, backticks, colons, and newlines survive verbatim.
#     Trailing newlines are trimmed because Slack renders them as blank lines.
#   * The token is read from a sops-managed file and passed to curl through a
#     stdin config file, never on the command line, so it stays out of `ps`
#     output and out of the shell history.
#   * The script never edits and never deletes. A user token grants both, so
#     leaving them out is what keeps them unreachable.
#   * On a policy violation the helper exits 64 with a single-line reason on
#     stderr. A Slack API error exits 1 and prints the `error` field Slack
#     returned, because `channel_not_found` is not a policy violation.
#
# Standalone test, from this directory:
#
#   bash slack-post-tests.sh

readonly EX_POLICY=64
readonly SLACK_POST_MESSAGE_ENDPOINT="https://slack.com/api/chat.postMessage"
readonly SLACK_OPEN_CONVERSATION_ENDPOINT="https://slack.com/api/conversations.open"

readonly RE_CHANNEL_ID='^[CDG][A-Z0-9]{7,}$'
readonly RE_CHANNEL_NAME='^#?[a-z0-9][a-z0-9._-]{0,79}$'
readonly RE_USER_ID='^U[A-Z0-9]{7,}$'
readonly RE_THREAD_TS='^[0-9]{10,11}\.[0-9]{6}$'

die() {
	printf 'slack-post: %s\n' "$*" >&2
	exit "${EX_POLICY}"
}

usage() {
	cat <<'EOF'
slack-post: post one message to Slack as the token owner.

USAGE
    slack-post <target> --body-file PATH [--thread-ts TS]
    slack-post <message-url> --body-file PATH
    slack-post --help

TARGETS
    C0ABEN38TRB                 a channel or DM ID
    '#eng-fulfillment-automation'  a public channel by name
    U08V6EV65TQ                 a person, by user ID; opens the DM first
    https://acme.slack.com/archives/C0ABEN38TRB/p1785267943715149
                                replies inside that message's thread

EXAMPLE
    slack-post C0ABEN38TRB --body-file message.md
    slack-post C0ABEN38TRB --body-file reply.md --thread-ts 1785267943.715149
    slack-post U08V6EV65TQ --body-file dm.md

POLICY
    The argument list is fixed and every argument is validated. Every token
    beginning with `-` is rejected except `--body-file` and `--thread-ts` in
    their expected positions. The body file must be an existing, readable,
    non-empty regular file. `--thread-ts` is rejected alongside a URL, because
    the URL already names the thread.

    Only chat.postMessage and conversations.open are reachable. Both endpoints
    are fixed in the script. conversations.open is called with a user ID only.
    The script never edits and never deletes a message.

TOKEN
    Read from the sops-managed file named in SLACK_POST_TOKEN_FILE, which the
    Nix wrapper sets. The token must be a user OAuth token (xoxp-) holding the
    chat:write user scope, so Slack attributes the message to its owner.
    Addressing a person by user ID also needs the im:write scope.
EOF
}

if [ "$#" -eq 1 ] && { [ "$1" = "--help" ] || [ "$1" = "-h" ]; }; then
	usage
	exit 0
fi

case "$#" in
3 | 5) ;;
*) die "expected 3 or 5 arguments: <target> --body-file PATH [--thread-ts TS]" ;;
esac

target="$1"
body_flag="$2"
body_file="$3"
thread_flag="${4:-}"
thread_ts="${5:-}"

case "${target}" in
-*) die "target may not begin with '-': ${target}" ;;
esac

[ "${body_flag}" = "--body-file" ] || die "second argument must be --body-file, got: ${body_flag}"

case "${body_file}" in
-*) die "body file may not begin with '-': ${body_file}" ;;
esac

if [ "$#" -eq 5 ]; then
	[ "${thread_flag}" = "--thread-ts" ] || die "fourth argument must be --thread-ts, got: ${thread_flag}"
	case "${thread_ts}" in
	-*) die "thread timestamp may not begin with '-': ${thread_ts}" ;;
	esac
fi

[ -f "${body_file}" ] || die "body file is not a regular file: ${body_file}"
[ -r "${body_file}" ] || die "body file is not readable: ${body_file}"
[ -s "${body_file}" ] || die "body file is empty: ${body_file}"

# Resolve the target. A message URL carries both the channel and the thread, so
# it is parsed first; everything else is a direct target.
channel=""
user_id=""
case "${target}" in
http://* | https://*)
	[ "$#" -eq 3 ] || die "--thread-ts is not accepted with a URL; the URL already names the thread"

	# Require the archives form. The channel and the timestamp are read out of
	# the path, and both are validated below rather than trusted as parsed.
	if [[ ! ${target} =~ ^https://[A-Za-z0-9.-]+\.slack\.com/archives/([CDG][A-Z0-9]{7,})/p([0-9]{16,17})([?][^[:space:]]*)?$ ]]; then
		die "not a Slack message URL: ${target}"
	fi
	channel="${BASH_REMATCH[1]}"
	url_digits="${BASH_REMATCH[2]}"
	url_query="${BASH_REMATCH[3]:-}"

	# A reply inside a thread carries the parent in thread_ts. Prefer it, so a
	# reply lands in the thread rather than starting a new one.
	if [[ ${url_query} =~ [?\&]thread_ts=([0-9]{10,11}\.[0-9]{6}) ]]; then
		thread_ts="${BASH_REMATCH[1]}"
	else
		# The path timestamp drops the dot: p1785267943715149 is
		# 1785267943.715149, always six digits of microseconds.
		thread_ts="${url_digits:0:${#url_digits}-6}.${url_digits: -6}"
	fi
	;;
*)
	if [[ ${target} =~ ${RE_USER_ID} ]]; then
		user_id="${target}"
	elif [[ ${target} =~ ${RE_CHANNEL_ID} ]] || [[ ${target} =~ ${RE_CHANNEL_NAME} ]]; then
		channel="${target}"
	else
		die "target must be a channel ID, a channel name, a user ID, or a Slack message URL: ${target}"
	fi
	;;
esac

if [ -n "${thread_ts}" ] && [[ ! ${thread_ts} =~ ${RE_THREAD_TS} ]]; then
	die "thread timestamp must look like 1785267943.715149, got: ${thread_ts}"
fi

[ -n "${SLACK_POST_TOKEN_FILE:-}" ] || die "SLACK_POST_TOKEN_FILE is unset"
[ -r "${SLACK_POST_TOKEN_FILE}" ] || die "token file is not readable: ${SLACK_POST_TOKEN_FILE}"

token="$(tr -d '\r\n' <"${SLACK_POST_TOKEN_FILE}")"
[ -n "${token}" ] || die "token file is empty: ${SLACK_POST_TOKEN_FILE}"

case "${token}" in
xoxp-*) ;;
xoxe.xoxp-*)
	die "token is an app configuration token, which only calls apps.manifest.* and tooling.tokens.*; copy the User OAuth Token from the app's OAuth & Permissions page instead"
	;;
xoxe-*)
	die "token is a refresh token, not an access token"
	;;
xoxb-*)
	die "token is a bot token, so Slack would post as the app; a xoxp- user token is required so the message comes from you"
	;;
*) die "token is not a user OAuth token; a xoxp- token is required so Slack attributes the message to you" ;;
esac

# Call one of the two fixed endpoints. curl reads the Authorization header from
# stdin so the token never appears in the process list. The payload is not
# secret and stays on the command line.
slack_api() {
	local endpoint="$1"
	local payload="$2"
	local response

	response="$(
		printf 'header = "Authorization: Bearer %s"\n' "${token}" |
			curl \
				--config - \
				--silent \
				--show-error \
				--max-time 30 \
				--header 'Content-Type: application/json; charset=utf-8' \
				--data "${payload}" \
				"${endpoint}"
	)"

	if [ -z "${response}" ]; then
		printf 'slack-post: no response from Slack\n' >&2
		exit 1
	fi

	if [ "$(printf '%s' "${response}" | jq -r '.ok')" != "true" ]; then
		printf 'slack-post: Slack rejected the request: %s\n' \
			"$(printf '%s' "${response}" | jq -r '.error // "unknown error"')" >&2
		exit 1
	fi

	printf '%s' "${response}"
}

# A user ID names a person, not a conversation, so open the DM to get its
# channel ID. Slack returns the existing DM when one is already open.
if [ -n "${user_id}" ]; then
	channel="$(
		slack_api "${SLACK_OPEN_CONVERSATION_ENDPOINT}" \
			"$(jq -c -n --arg users "${user_id}" '{users: $users, return_im: true}')" |
			jq -r '.channel.id'
	)"
	[ -n "${channel}" ] && [ "${channel}" != "null" ] || die "could not open a DM with ${user_id}"
fi

# Build the payload with jq so every character in the body survives. Trailing
# newlines are trimmed because Slack renders them as blank lines. The output is
# compact so the request body stays one argument on one line.
payload="$(
	jq -c -n \
		--arg channel "${channel}" \
		--arg thread_ts "${thread_ts}" \
		--rawfile body "${body_file}" \
		'{
      channel: $channel,
      text: ($body | sub("[\n]+$"; "")),
      mrkdwn: true,
      unfurl_links: true,
      unfurl_media: true
    }
    + (if $thread_ts == "" then {} else {thread_ts: $thread_ts} end)'
)"

response="$(slack_api "${SLACK_POST_MESSAGE_ENDPOINT}" "${payload}")"

printf 'channel: %s\n' "$(printf '%s' "${response}" | jq -r '.channel')"
printf 'ts: %s\n' "$(printf '%s' "${response}" | jq -r '.ts')"
if [ -n "${thread_ts}" ]; then
	printf 'thread_ts: %s\n' "${thread_ts}"
fi
