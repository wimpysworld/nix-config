{ pkgs }:

let
  chromiumWrapper = pkgs.writeShellApplication {
    name = "chromium";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      runtime_dir="''${FENCE_CHROMIUM_RUNTIME_DIR:-}"
      if [ -z "$runtime_dir" ]; then
        runtime_dir="$(mktemp -d "''${TMPDIR:-/tmp}/fence-chromium.XXXXXX")"
      fi

      mkdir -p \
        "$runtime_dir/home" \
        "$runtime_dir/config" \
        "$runtime_dir/cache" \
        "$runtime_dir/data" \
        "$runtime_dir/state" \
        "$runtime_dir/runtime" \
        "$runtime_dir/profile" \
        "$runtime_dir/crash"
      chmod 700 \
        "$runtime_dir" \
        "$runtime_dir/home" \
        "$runtime_dir/config" \
        "$runtime_dir/cache" \
        "$runtime_dir/data" \
        "$runtime_dir/state" \
        "$runtime_dir/runtime" \
        "$runtime_dir/profile" \
        "$runtime_dir/crash"

      export HOME="$runtime_dir/home"
      export XDG_CONFIG_HOME="$runtime_dir/config"
      export XDG_CACHE_HOME="$runtime_dir/cache"
      export XDG_DATA_HOME="$runtime_dir/data"
      export XDG_STATE_HOME="$runtime_dir/state"
      export XDG_RUNTIME_DIR="$runtime_dir/runtime"

      has_user_data_dir=0
      for arg in "$@"; do
        case "$arg" in
          --user-data-dir | --user-data-dir=*)
            has_user_data_dir=1
            break
            ;;
        esac
      done

      user_data_dir_arg=()
      if [ "$has_user_data_dir" != 1 ]; then
        user_data_dir_arg=(--user-data-dir="$runtime_dir/profile")
      fi

      sandbox_arg=(--disable-setuid-sandbox)
      if [ "''${NYALA_DEBUG_CHROMIUM_NO_SANDBOX:-0}" = "1" ] || [ "''${FENCE_DEBUG_CHROMIUM_NO_SANDBOX:-0}" = "1" ]; then
        sandbox_arg=(--no-sandbox)
      fi

      exec ${pkgs.chromium}/bin/chromium \
        "''${sandbox_arg[@]}" \
        --disable-crash-reporter \
        --disable-breakpad \
        --disable-dev-shm-usage \
        --crash-dumps-dir="$runtime_dir/crash" \
        "''${user_data_dir_arg[@]}" \
        "$@"
    '';
  };
in
{
  runtimeInputs = [
    pkgs.coreutils
    chromiumWrapper
  ];

  setupShell = ''
    fence_chromium_runtime_dir="$(mktemp -d "''${TMPDIR:-/tmp}/fence-chromium.XXXXXX")"
    chmod 700 "$fence_chromium_runtime_dir"

    fence_args+=(--expose-host-path-rw "$fence_chromium_runtime_dir")
    fence_env+=(
      "FENCE_CHROMIUM_RUNTIME_DIR=$fence_chromium_runtime_dir"
      "NOUGHTY_AGENT_ISOLATION=Fenced"
      "NYALA_BROWSER=${chromiumWrapper}/bin/chromium"
      "CHROME_PATH=${chromiumWrapper}/bin/chromium"
      "NYALA_DEBUG_CHROMIUM_NO_SANDBOX=''${NYALA_DEBUG_CHROMIUM_NO_SANDBOX:-0}"
      "FENCE_DEBUG_CHROMIUM_NO_SANDBOX=''${FENCE_DEBUG_CHROMIUM_NO_SANDBOX:-0}"
      "PATH=${chromiumWrapper}/bin:$PATH"
    )
  '';
}
