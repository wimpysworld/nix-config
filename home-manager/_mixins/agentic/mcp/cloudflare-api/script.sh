set +x

token_file=@apiTokenPath@
if [[ ! -f "$token_file" || ! -r "$token_file" ]]; then
  printf '%s\n' 'cloudflare-api: API token file is missing or unreadable.' >&2
  exit 1
fi

if ! token="$(cat -- "$token_file")"; then
  printf '%s\n' 'cloudflare-api: cannot read API token file.' >&2
  exit 1
fi
if [[ -z "$token" ]]; then
  printf '%s\n' 'cloudflare-api: API token file is empty.' >&2
  exit 1
fi

export API_ACCESS_TOKEN="$token"
# Prevent HTTPX from constructing an unused SOCKS fallback while keeping the HTTP proxy route.
if [[ "${https_proxy-${HTTPS_PROXY-}}" == http://* && "${http_proxy-${HTTP_PROXY-}}" == http://* ]]; then
  unset ALL_PROXY all_proxy
fi
exec @mcpProxy@ --transport streamablehttp https://mcp.cloudflare.com/mcp
