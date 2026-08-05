# Logging wrapper around xdg-open for the Kolide launcher desktop process.
# The launcher discards xdg-open output and never checks its exit status
# (kolide/launcher issue 2430), so failures are silent. Each invocation is
# logged with its arguments and environment to aid diagnosis. Logging must
# never break the open itself; the log file may be owned by another user.
# The log captures auth tokens from the environment and one-time codes
# from URL arguments, so it must stay private: prefer the user-only
# XDG_RUNTIME_DIR (mode 0700) and create the file 0600 via umask even on
# the /tmp fallback.
umask 077
if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
  LOG_FILE="${XDG_RUNTIME_DIR}/kolide-xdg-open.log"
else
  LOG_FILE="/tmp/kolide-xdg-open.log"
fi

{
  printf '=== %s ===\n' "$(date --iso-8601=seconds)"
  printf 'args: %s\n' "$*"
  env
  printf '\n'
} >>"${LOG_FILE}" 2>/dev/null || true

# The desktop process environment lacks a session bus address; derive the
# conventional one from the runtime directory so portals and gio work.
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
  export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
fi

# xdg-open picks its handler strategy from XDG_CURRENT_DESKTOP, which the
# desktop process does not inherit. KOLIDE_XDG_CURRENT_DESKTOP is baked in
# at build time from the host registry; leave the variable unset when the
# desktop is unknown so xdg-open falls back to its generic path.
if [ -z "${XDG_CURRENT_DESKTOP:-}" ] && [ -n "${KOLIDE_XDG_CURRENT_DESKTOP}" ]; then
  export XDG_CURRENT_DESKTOP="${KOLIDE_XDG_CURRENT_DESKTOP}"
fi

# runtimeInputs prepends the real xdg-utils to PATH inside this script, so
# exec resolves to it rather than looping back into this wrapper. Only
# append stderr to the log when the log is writable by this user.
if { true >>"${LOG_FILE}"; } 2>/dev/null; then
  exec xdg-open "$@" 2>>"${LOG_FILE}"
else
  exec xdg-open "$@"
fi
