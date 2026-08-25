{
  coreutils,
  herdr,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "herdr-integrations";
  inherit (herdr) version;

  dontUnpack = true;
  dontPatchShebangs = true;

  nativeBuildInputs = [ herdr ];

  installPhase = ''
    runHook preInstall

    export HOME="$out/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    export PI_CODING_AGENT_DIR="$HOME/.pi/agent"
    export CODEX_HOME="$HOME/.codex"
    export CLAUDE_CONFIG_DIR="$HOME/.claude"

    mkdir -p \
      "$XDG_CONFIG_HOME/opencode" \
      "$PI_CODING_AGENT_DIR" \
      "$CODEX_HOME" \
      "$CLAUDE_CONFIG_DIR"

    runHerdr() {
      env -i \
        "PATH=${
          lib.makeBinPath [
            coreutils
            herdr
          ]
        }" \
        "HOME=$HOME" \
        "XDG_CONFIG_HOME=$XDG_CONFIG_HOME" \
        "PI_CODING_AGENT_DIR=$PI_CODING_AGENT_DIR" \
        "CODEX_HOME=$CODEX_HOME" \
        "CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR" \
        "NO_COLOR=1" \
        herdr "$@"
    }

    for target in pi opencode codex claude; do
      runHerdr integration install "$target"
    done

    expectedFiles=(
      "$CLAUDE_CONFIG_DIR/hooks/herdr-agent-state.sh"
      "$CLAUDE_CONFIG_DIR/settings.json"
      "$CODEX_HOME/config.toml"
      "$CODEX_HOME/herdr-agent-state.sh"
      "$CODEX_HOME/hooks.json"
      "$XDG_CONFIG_HOME/opencode/herdr-tui-session.js"
      "$XDG_CONFIG_HOME/opencode/plugins/herdr-agent-state.js"
      "$XDG_CONFIG_HOME/opencode/tui.jsonc"
      "$PI_CODING_AGENT_DIR/extensions/herdr-agent-state.ts"
    )

    for expectedFile in "''${expectedFiles[@]}"; do
      test -f "$expectedFile"
    done

    actualFileCount="$(find "$HOME" -type f -print | wc -l)"
    test "$actualFileCount" -eq "''${#expectedFiles[@]}"

    statusOutput="$(runHerdr integration status)"
    for target in pi opencode codex claude; do
      if [[ "$statusOutput" != *"$target: current "* ]]; then
        printf '%s\n' "$statusOutput" >&2
        exit 1
      fi
    done

    runHook postInstall
  '';

  meta = {
    description = "Integration files for coding agents that match the Herdr release";
    inherit (herdr.meta)
      changelog
      homepage
      license
      platforms
      ;
    maintainers = with lib.maintainers; [ flexiondotorg ];
  };
}
