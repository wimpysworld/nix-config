{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;

  # The Paseo daemon runs for martin only, gated on the host tag. The desktop
  # client is available on laptops and workstations. The CLI ships wherever
  # either is active.
  isMartin = noughtyLib.isUser [ "martin" ];
  serverEnabled = isMartin && noughtyLib.hostHasTag "paseo";
  desktopEnabled = isMartin && host.is.linux && (host.is.workstation || host.is.laptop);
  cliEnabled = serverEnabled || desktopEnabled;

  username = config.noughty.user.name;
  homeDir = config.home.homeDirectory;
  paseoHome = "${homeDir}/.paseo";
  paseoAgentBin = "${homeDir}/.nix-profile/bin";

  # Daemon config written to $PASEO_HOME/config.json at start. Relay stays on by
  # default, so the settings here register the fenced providers, hide the unused
  # Copilot provider, and turn voice off.
  paseoSettings = {
    agents.providers = {
      copilot.enabled = false;
      claude-fenced = {
        extends = "claude";
        label = "Claude (Fenced)";
        command = [ "${paseoAgentBin}/claude-fenced" ];
        order = 10;
      };
      codex-fenced = {
        extends = "codex";
        label = "Codex (Fenced)";
        command = [ "${paseoAgentBin}/codex-fenced" ];
        order = 20;
      };
      opencode-fenced = {
        extends = "opencode";
        label = "OpenCode (Fenced)";
        command = [ "${paseoAgentBin}/opencode-fenced" ];
        order = 30;
      };
      pi-fenced = {
        extends = "pi";
        label = "Pi (Fenced)";
        command = [ "${paseoAgentBin}/pi-fenced" ];
        order = 40;
      };
    };

    # No voice support. Paseo's only local speech engine is parakeet/kokoro via
    # sherpa-onnx, which this package does not build, and we run no remote
    # speech services. Both flags default to true, so disable them explicitly to
    # stop the speech runtime starting and degrading. Voice is deferred until a
    # shared local Whisper backend is in place (see Voxtype).
    features = {
      dictation.enabled = false;
      voiceMode.enabled = false;
    };

    # Inject the loopback MCP tools into launched agents so they can drive other
    # agents. Keep worktrees under ~/Development so they sit inside the fence
    # sandbox. A "~" path would resolve against PASEO_HOME, so use an absolute
    # path which the daemon keeps as-is.
    daemon.mcp.injectIntoAgents = true;
    worktrees.root = "${homeDir}/Development/Paseo/worktrees";
  };
  paseoConfigFile = pkgs.writeText "paseo-config.json" (builtins.toJSON paseoSettings);

  # Spawned agents (claude-fenced and friends) live in the user profile, which a
  # systemd user unit does not put on PATH by default.
  paseoPath = lib.concatStringsSep ":" [
    "${homeDir}/.nix-profile/bin"
    "${homeDir}/.local/state/nix/profile/bin"
    "/etc/profiles/per-user/${username}/bin"
    "/run/current-system/sw/bin"
    "/run/wrappers/bin"
    "/nix/var/nix/profiles/default/bin"
  ];

  paseoPreStart = pkgs.writeShellScript "paseo-prestart" ''
    ${pkgs.coreutils}/bin/mkdir -p ${paseoHome}
    ${pkgs.coreutils}/bin/install -m 0600 ${paseoConfigFile} ${paseoHome}/config.json
  '';

  # The desktop app owns ~/.config/Paseo/desktop-settings.json and rewrites it
  # at runtime, so it cannot be a managed symlink.
  paseoUserDataDir = "${config.xdg.configHome}/Paseo";
in
{
  config = lib.mkMerge [
    (lib.mkIf cliEnabled {
      home.packages = [ pkgs.paseo ];
    })

    (lib.mkIf serverEnabled {
      home.shellAliases.paseo-log = "journalctl --user -u paseo.service";

      # The daemon binds loopback only and reaches clients over the relay, where
      # pairing keys provide auth. A password matters only for LAN or VPN binds,
      # so it is omitted; the local CLI then connects without credentials.
      systemd.user.services.paseo = {
        Unit.Description = "Paseo - self-hosted daemon for AI coding agents";
        Service = {
          Type = "simple";
          ExecStartPre = "${paseoPreStart}";
          ExecStart = "${pkgs.paseo}/bin/paseo-server";
          Environment = [
            "PASEO_HOME=${paseoHome}"
            "PATH=${paseoPath}"
          ];
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };
    })

    (lib.mkIf desktopEnabled {
      home.packages = [ pkgs.paseo-desktop ];
    })

    # Only where the desktop app shares a host with our daemon: stop the app
    # starting its own bundled daemon, which would clash on the daemon port.
    # The app rewrites this file at runtime, so re-apply the keys on activation
    # and keep whatever else it added.
    (lib.mkIf (serverEnabled && desktopEnabled) {
      home.activation.paseoDesktopClientSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        settings_file="${paseoUserDataDir}/desktop-settings.json"
        mkdir -p "$(dirname "$settings_file")"
        current="$(${pkgs.jq}/bin/jq '.' "$settings_file" 2>/dev/null || echo '{}')"
        ${pkgs.jq}/bin/jq '
          .version = 1
          | .settings.releaseChannel //= "stable"
          | .settings.daemon.manageBuiltInDaemon = false
          | .settings.daemon.keepRunningAfterQuit = false
          | .migrations.legacyRendererSettingsImported = true
        ' <<<"$current" >"$settings_file.tmp"
        chmod 0600 "$settings_file.tmp"
        mv "$settings_file.tmp" "$settings_file"
      '';
    })
  ];
}
