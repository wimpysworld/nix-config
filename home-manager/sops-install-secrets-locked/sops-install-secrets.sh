upstream=@upstream@
flock=@flock@
lockDir=@lockDir@

# Upstream checks manifests during builds, where the user home is unavailable.
if [[ $# -eq 2 && ( $1 == -check-mode=sopsfile || $1 == -check-mode=manifest ) ]]; then
  exec "$upstream" "$@"
fi

originalUmask=$(umask)
umask 077
if [[ -L "$lockDir" ]]; then
  echo "sops-install-secrets: lock directory must not be a symlink: $lockDir" >&2
  exit 1
fi
mkdir -p -- "$lockDir"
if [[ -L "$lockDir" || ! -d "$lockDir" || ! -O "$lockDir" ]]; then
  echo "sops-install-secrets: lock directory must be owned by the current user: $lockDir" >&2
  exit 1
fi
chmod 0700 -- "$lockDir"

lockFile="$lockDir/install.lock"
if [[ -L "$lockFile" || ( -e "$lockFile" && ( ! -f "$lockFile" || ! -O "$lockFile" ) ) ]]; then
  echo "sops-install-secrets: lock must be an owned regular file: $lockFile" >&2
  exit 1
fi
: >> "$lockFile"
chmod 0600 -- "$lockFile"
umask "$originalUmask"

exec "$flock" -x "$lockFile" "$upstream" "$@"
