set +x
umask 077

rustdesk=/Applications/RustDesk.app/Contents/MacOS/RustDesk

# Both launchd sessions and the provisioner must reject a user-writable app.
if ! python3 -I - <<'PY'
import os
from pathlib import Path
import stat
import sys

app = Path("/Applications/RustDesk.app")

def check(path):
    metadata = path.lstat()
    if metadata.st_uid != 0:
        raise ValueError("non-root owner")
    if path.is_symlink():
        if not path.resolve(strict=True).is_relative_to(app):
            raise ValueError("external symlink")
    elif metadata.st_mode & 0o022:
        raise ValueError("group or world write permission")
    elif not (stat.S_ISDIR(metadata.st_mode) or stat.S_ISREG(metadata.st_mode)):
        raise ValueError("unsupported file type")

try:
    if app.is_symlink() or not app.is_dir():
        raise ValueError("missing app or symlink")
    check(app)
    def walk_error(error):
        raise error
    for directory, directories, files in os.walk(app, onerror=walk_error):
        for name in directories + files:
            check(Path(directory) / name)
except (OSError, ValueError, RuntimeError):
    sys.exit("RustDesk is missing or is not root-owned and protected. Run system activation before starting its services.")
PY
then
    exit 1
fi

if [[ "${1:-}" == "--check-app" ]]; then
    exit 0
fi
password_file=$1

# The shared descriptor retains the lock after the Python process exits.
exec 9>/var/run/rustdesk-configure.lock
if ! timeout 150 python3 -I -c 'import fcntl; fcntl.flock(9, fcntl.LOCK_EX)'; then
    echo "Another RustDesk configuration process did not finish within 150 seconds." >&2
    exit 1
fi

configure_rustdesk() {
    [[ -x "$rustdesk" && -s "$password_file" ]] || return 1
    local password result key value
    password=$(< "$password_file")
    [[ -n "$password" ]] || return 1

    # RustDesk reports CLI errors through stdout with a successful exit status.
    result=$(timeout 3 "$rustdesk" --password "$password" 2>/dev/null) || return 1
    unset password
    [[ "$result" == "Done!" ]] || return 1

    while read -r key value; do
        timeout 3 "$rustdesk" --option "$key" "$value" >/dev/null 2>&1 || return 1
        result=$(timeout 3 "$rustdesk" --option "$key" 2>/dev/null) || return 1
        [[ "$result" == "$value" ]] || return 1
    done <<'OPTIONS'
verification-method use-permanent-password
approve-mode password
direct-access-port 21118
direct-server Y
OPTIONS
}

for attempt in {1..5}; do
    if configure_rustdesk; then
        echo "RustDesk password and direct-access settings applied."
        exit 0
    fi
    if [[ "$attempt" -lt 5 ]]; then
        sleep 2
    fi
done

echo "RustDesk configuration failed. Check the app, secret and server services, then run configure-rustdesk as root." >&2
exit 1
