if [[ "$(uname -s)" != Darwin ]]; then
  echo "Mac App Store installation requires macOS." >&2
  exit 1
fi
if [[ "$(id -u)" == 0 ]]; then
  echo "Run switch-mas as ${primary_user}, not root." >&2
  exit 1
fi
if [[ "$(id -un)" != "$primary_user" ]]; then
  echo "Run switch-mas as ${primary_user}." >&2
  exit 1
fi
if [[ $# != 0 ]]; then
  echo "switch-mas accepts no arguments." >&2
  exit 1
fi
if [[ ! -s "$manifest" ]]; then
  echo "No Mac App Store apps are configured."
  exit 0
fi

echo "Sign in to the App Store manually before installation."
while IFS=$'\t' read -r app_id app_name; do
  printf 'Installing %s (%s)\n' "$app_name" "$app_id"
  if ! mas get "$app_id"; then
    printf 'Installation failed for %s. Check your App Store sign-in and retry.\n' "$app_name" >&2
    exit 1
  fi
done < "$manifest"
