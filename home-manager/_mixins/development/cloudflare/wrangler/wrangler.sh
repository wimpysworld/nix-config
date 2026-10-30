if [[ $# -eq 1 ]]; then
  case "$1" in
    --help|-h|--version|-v)
      exec @wrangler@ "$@"
      ;;
  esac
fi

load_credential() {
  local name="$1" path="$2" value
  if [[ -n "${!name:-}" ]]; then
    return
  fi
  if [[ ! -f "$path" || ! -r "$path" ]]; then
    printf 'wrangler: %s is unset and its managed secret file is unavailable: %s\n' "$name" "$path" >&2
    exit 1
  fi
  if ! value=$(< "$path") || [[ -z "$value" ]]; then
    printf 'wrangler: the managed secret for %s is empty or unreadable.\n' "$name" >&2
    exit 1
  fi
  printf -v "$name" '%s' "$value"
  export "${name?}"
}

load_credential CLOUDFLARE_ACCOUNT_ID @accountIdPath@
load_credential CLOUDFLARE_API_TOKEN @apiTokenPath@

exec @wrangler@ "$@"
