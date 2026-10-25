export OPENCODE_DISABLE_MODELS_FETCH=1
opencode_args=("$@")
opencode_command=""
opencode_leaf=""
opencode_insert=0
opencode_directory="$PWD"
opencode_resume=1
opencode_remote=0
opencode_standalone=0
opencode_help=0
opencode_positional=0
for ((i = 0; i < ${#opencode_args[@]}; i++)); do
  arg="${opencode_args[i]}"
  if (( ! opencode_positional )); then
    case "$arg" in
      --server | --server=*) opencode_remote=1 ;;
      -h | --help | -v | --version) opencode_help=1 ;;
      -c | --continue | --no-continue | --continue=* | -s | --session | --session=* | --fork | --fork=*) opencode_resume=0 ;;
      --standalone | --standalone=true)
        opencode_standalone=$((i + 1))
        if [[ "${opencode_args[i + 1]:-}" =~ ^(false|0|no|off)$ ]]; then
          echo "OpenCode: shared-server selection is not supported. Use --server explicitly outside Fence." >&2
          exit 2
        fi
        ;;
      --standalone=* | --no-standalone | --no-standalone=*)
        echo "OpenCode: shared-server selection is not supported. Use --server explicitly outside Fence." >&2
        exit 2
        ;;
    esac
    case "$arg" in
      --directory)
        opencode_directory="${opencode_args[i + 1]:-}"
        ;;
      --directory=*) opencode_directory="${arg#*=}" ;;
    esac
    case "$arg" in
      --server | -s | --session | --prompt | --model | -m | --agent | --log-level | --directory | --format | --method | --answer | --data | -d | --header | -H | --param | --file | -f | --title | --days | --year | --project | --limit | --max-count | -n | --replay-limit | --url | --env | --hostname | --port | --cors)
        i=$((i + 1))
        continue
        ;;
      --) opencode_positional=1; continue ;;
      -*) continue ;;
    esac
  fi
  if [[ -z "$opencode_command" ]]; then
    if (( ! opencode_positional )); then
      case "$arg" in
        upgrade | update | uninstall | acp | api | debug | auth | mcp | plugin | models | stats | mini | run | session | service | reload | pair | serve)
          opencode_command="$arg"
          opencode_insert=$((i + 1))
          continue
          ;;
      esac
    fi
    opencode_command=root
    opencode_directory="$arg"
  elif [[ -z "$opencode_leaf" ]]; then
    case "$opencode_command" in
      auth | session)
        opencode_leaf="$arg"
        opencode_insert=$((i + 1))
        ;;
    esac
  fi
done
opencode_command="${opencode_command:-root}"
opencode_directory="$(cd -- "$opencode_directory" && pwd -P)"
case "$opencode_directory" in
  @trustedRoots@) ;;
  *) export OPENCODE_DISABLE_PROJECT_CONFIG=1 ;;
esac
opencode_private=0
case "$opencode_command:$opencode_leaf" in
  root: | mini: | run: | api: | models: | stats: | reload: | auth:list | auth:login | auth:logout | auth:export | auth:import | auth:switch | session:list | session:delete | session:export | session:import)
    opencode_private=1
    ;;
esac
if [[ "${FENCE_SANDBOX:-0}" == 1 ]] && (( ! opencode_help )); then
  if ((opencode_remote)); then
    echo "OpenCode: Fence cannot attach to an external server." >&2
    exit 2
  fi
  if (( ! opencode_private )) && [[ "$opencode_command" != acp ]]; then
    echo "OpenCode: this command has no private-server contract inside Fence." >&2
    exit 2
  fi
fi
opencode_flags=()
if (( ! opencode_help )); then
  if ((opencode_private && ! opencode_remote && opencode_standalone <= opencode_insert)); then
    opencode_flags+=(--standalone)
  fi
  case "$opencode_command" in
    root | mini)
      if ((opencode_resume)); then opencode_flags+=(--continue); fi
      ;;
  esac
fi
# Nested commands own their server flags, not the enclosing command group.
exec @opencode@ "${opencode_args[@]:0:opencode_insert}" "${opencode_flags[@]}" "${opencode_args[@]:opencode_insert}"
