# shellcheck shell=bash
# gh-dispatch: apply the GitHub command policy inside Fence.

: "${GH_DISPATCH_GH:?GH_DISPATCH_GH must name the private gh backend}"
: "${GH_DISPATCH_API_SAFE:?GH_DISPATCH_API_SAFE must name gh-api-safe}"

readonly GH_DISPATCH_GH GH_DISPATCH_API_SAFE
export GH_TELEMETRY=false

if [[ ${FENCE_SANDBOX:-0} != 1 ]]; then
	exec "${GH_DISPATCH_GH}" "$@"
fi

die() {
	printf 'gh: blocked by Fence policy: %s\n' "$*" >&2
	exit 64
}

# Find the command words after the persistent repository and hostname flags.
# The real CLI accepts these flags before a command or its subcommand.
command_words=()
command_index=-1
skip_value=0
after_options=0
index=0
for token in "$@"; do
	if ((skip_value)); then
		skip_value=0
		index=$((index + 1))
		continue
	fi

	if ((!after_options)); then
		case "${token}" in
		--)
			after_options=1
			index=$((index + 1))
			continue
			;;
		-R | --repo | -h | --hostname)
			skip_value=1
			index=$((index + 1))
			continue
			;;
		-R?* | -h?* | --repo=* | --hostname=* | --help | --version)
			index=$((index + 1))
			continue
			;;
		-*)
			index=$((index + 1))
			continue
			;;
		esac
	fi

	if ((${#command_words[@]} == 0)); then
		command_index=${index}
	fi
	command_words+=("${token}")
	if ((${#command_words[@]} == 3)); then
		break
	fi
	index=$((index + 1))
done

command_name=${command_words[0]:-}
subcommand=${command_words[1]:-}
third_command=${command_words[2]:-}

# Raw API requests use the read-only wrapper. `api` has no persistent
# repository flag, so a prefixed command is invalid and is rejected here.
if [[ ${command_name} == api ]]; then
	if ((command_index != 0)); then
		die 'gh api with flags before api'
	fi
	exec "${GH_DISPATCH_API_SAFE}" "${@:2}"
fi

case "${command_name}" in
agent-task)
	case "${subcommand}" in
	list | view) ;;
	*) die 'gh agent-task' ;;
	esac
	;;
alias)
	case "${subcommand}" in
	delete | import | set) die "gh ${command_name} ${subcommand}" ;;
	esac
	;;
auth)
	if [[ ${subcommand} == setup-git ]]; then
		die 'gh auth setup-git'
	fi
	if [[ ${subcommand} == login ]]; then
		for token in "$@"; do
			case "${token}" in
			--with-token | --with-token=*) die 'gh auth login --with-token' ;;
			esac
		done
	fi
	;;
cache)
	if [[ ${subcommand} == delete ]]; then
		die 'gh cache delete'
	fi
	;;
codespace | cs)
	case "${subcommand}" in
	list | view) ;;
	*) die "gh ${command_name}" ;;
	esac
	;;
copilot)
	die 'gh copilot'
	;;
config)
	die 'gh config'
	;;
extension | extensions | ext)
	case "${subcommand}" in
	browse | list | search) ;;
	*) die "gh ${command_name}" ;;
	esac
	;;
gist)
	case "${subcommand}" in
	create | delete | edit) die "gh gist ${subcommand}" ;;
	esac
	;;
gpg-key | ssh-key)
	[[ ${subcommand} == list ]] || die "gh ${command_name}"
	;;
issue)
	case "${subcommand}" in
	delete | lock | pin | transfer | unlock | unpin) die "gh issue ${subcommand}" ;;
	esac
	;;
label)
	case "${subcommand}" in
	list | view) ;;
	*) die 'gh label' ;;
	esac
	;;
pr)
	case "${subcommand}" in
	lock | merge | unlock) die "gh pr ${subcommand}" ;;
	esac
	;;
project)
	# Reads, plus the two item writes the task commands need: adding an
	# issue to a project and setting one field on an item. Project, field,
	# and view mutations stay denied.
	case "${subcommand}" in
	field-list | item-add | item-edit | item-list | list | view) ;;
	*) die 'gh project' ;;
	esac
	;;
release)
	case "${subcommand}" in
	download | list | view) ;;
	*) die 'gh release' ;;
	esac
	;;
repo)
	case "${subcommand}" in
	archive | create | delete | edit | new | rename | set-default | sync | unarchive)
		die "gh repo ${subcommand}"
		;;
	autolink)
		case "${third_command}" in
		create | delete | new) die "gh repo autolink ${third_command}" ;;
		esac
		;;
	deploy-key)
		[[ ${third_command} == list ]] || die 'gh repo deploy-key'
		;;
	esac
	;;
run)
	if [[ ${subcommand} == delete ]]; then
		die 'gh run delete'
	fi
	;;
secret)
	[[ ${subcommand} == list ]] || die 'gh secret'
	;;
skill)
	case "${subcommand}" in
	list | preview | search) ;;
	*) die 'gh skill' ;;
	esac
	;;
variable)
	case "${subcommand}" in
	get | list) ;;
	*) die 'gh variable' ;;
	esac
	;;
workflow)
	case "${subcommand}" in
	disable | enable | run) die "gh workflow ${subcommand}" ;;
	esac
	;;
esac

# Fence permits these built-in commands and managed extensions. Unknown names
# can be configured aliases or unmanaged extensions, so they stop here.
case "${command_name}" in
"" | agent-task | alias | attestation | auth | browse | cache | codespace | completion | cs | dash | discussion | enhance | ext | extension | extensions | gist | gpg-key | help | issue | label | licenses | markdown-preview | notify | org | pr | preview | project | release | repo | ruleset | run | search | secret | skill | ssh-key | status | variable | version | workflow) ;;
*) die "unknown gh command ${command_name}" ;;
esac

exec "${GH_DISPATCH_GH}" "$@"
