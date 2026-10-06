if [[ "$(/usr/bin/id -u)" != 0 ]]; then
  echo "Rosetta setup requires root activation." >&2
  exit 1
fi

rosetta_installed() {
  /usr/sbin/pkgutil --pkg-info com.apple.pkg.RosettaUpdateAuto >/dev/null 2>&1 \
    && [[ -f /Library/Apple/usr/libexec/oah/libRosettaRuntime ]]
}

if rosetta_installed; then
  exit 0
fi

version=$(/usr/bin/sw_vers -productVersion)
major=${version%%.*}
if [[ ! "$major" =~ ^[0-9]+$ ]] || (( major >= 28 )); then
  echo "Rosetta is missing. Review supported macOS versions before enabling installation on macOS ${version}." >&2
  exit 1
fi

echo "Installing Rosetta requires internet access and accepts the Apple Rosetta licence."
if ! /usr/sbin/softwareupdate --install-rosetta --agree-to-license; then
  echo "Rosetta installation failed. Check internet access and retry activation." >&2
  exit 1
fi
if ! rosetta_installed; then
  echo "Rosetta installation could not be verified. Activation cannot continue." >&2
  exit 1
fi
echo "Rosetta installation verified."
