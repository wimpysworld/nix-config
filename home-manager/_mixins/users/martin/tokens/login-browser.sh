url="$1"
if [[ -n "${MINT_LOGIN_HINT:-}" ]]; then
    separator='?'
    [[ "$url" != *'?'* ]] || separator='&'
    url+="${separator}login_hint=$(jq -rn --arg v "$MINT_LOGIN_HINT" '$v|@uri')"
fi
if command -v google-chrome-stable >/dev/null; then
    exec google-chrome-stable "$url"
fi
exec xdg-open "$url"
