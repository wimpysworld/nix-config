: "${handy_bin:?}" "${defaults_file:?}" "${managed_file:?}"

# Headless commands bypass upstream single-instance handling and must not edit a live store.
for argument in "$@"; do
  case "$argument" in
    --help|-h|--version|-V|--list-devices|--list-models|--transcribe-file|--transcribe-file=*|-f*)
      exec "$handy_bin" "$@"
      ;;
  esac
done

umask 077
data_dir="${XDG_DATA_HOME:-"$HOME/.local/share"}/com.pais.handy"
settings_file="$data_dir/settings_store.json"
mkdir -p "$data_dir"
exec 9>"$data_dir/.nix-launch.lock"
flock --exclusive 9

# Handy 0.9.8 uses tauri-plugin-single-instance 2.4.0 with this D-Bus interface.
bus_name=com.pais.handy.SingleInstance
bus_path=/com/pais/handy/SingleInstance
has_owner="$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus \
  org.freedesktop.DBus NameHasOwner s "$bus_name")"
case "$has_owner" in
  'b true')
    owner="$(busctl --user --json=short call org.freedesktop.DBus /org/freedesktop/DBus \
      org.freedesktop.DBus GetNameOwner s "$bus_name" | jq -er '.data[0]')"
    # Address the unique owner, so an exit cannot turn a command into an unmerged start.
    exec busctl --user --auto-start=no -- call "$owner" "$bus_path" \
      org.SingleInstance.DBus ExecuteCallback ass "$(( $# + 1 ))" "$handy_bin" "$@" "$PWD"
    ;;
  'b false') ;;
  *) echo 'handy: cannot determine the single-instance owner' >&2; exit 1 ;;
esac

existing_file="$defaults_file"
if [[ -e "$settings_file" || -L "$settings_file" ]]; then
  if [[ ! -f "$settings_file" || -L "$settings_file" || ! -r "$settings_file" ]]; then
    echo 'handy: settings store is not a readable regular file' >&2
    exit 1
  fi
  existing_file="$settings_file"
fi

temporary_file="$(mktemp "$data_dir/.settings_store.json.XXXXXX")"
trap 'rm -f -- "$temporary_file"' EXIT
if ! jq --compact-output --slurp \
  --slurpfile defaults "$defaults_file" --slurpfile managed "$managed_file" '
    if length != 1 then error("expected one store")
    elif (.[0] | type) != "object" then error("expected an object")
    elif (.[0].settings | type) != "object" then error("expected settings")
    else $defaults[0] * .[0] | .settings += $managed[0]
    end
  ' "$existing_file" > "$temporary_file" 2>/dev/null; then
  echo 'handy: invalid settings store, left unchanged' >&2
  exit 1
fi
chmod 0600 "$temporary_file"
mv -T -- "$temporary_file" "$settings_file"
trap - EXIT

"$handy_bin" "$@" 9>&- &
child=$!
gdbus wait --session "$bus_name" 9>&- &
readiness=$!
trap 'kill -TERM "$child" "$readiness" 2>/dev/null || true; wait || true; exit 143' TERM
trap 'kill -INT "$child" "$readiness" 2>/dev/null || true; wait || true; exit 130' INT

# Serialise startup until upstream owns its name, or the child exits.
status=0
wait -n -p completed "$child" "$readiness" || status=$?
if [[ "$completed" == "$child" ]]; then
  kill "$readiness" 2>/dev/null || true
  wait "$readiness" 2>/dev/null || true
  exit "$status"
fi
trap 'kill -TERM "$child" 2>/dev/null || true; wait "$child" || true; exit 143' TERM
trap 'kill -INT "$child" 2>/dev/null || true; wait "$child" || true; exit 130' INT
if [[ "$status" == 0 ]]; then
  flock --unlock 9
  exec 9>&-
else
  echo 'handy: single-instance readiness failed, retaining the startup lock until exit' >&2
fi
wait "$child"
