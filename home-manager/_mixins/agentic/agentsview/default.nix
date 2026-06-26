{
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (pkgs.stdenv.hostPlatform) system;
  agentsviewPackage = inputs.llm-agents.packages.${system}.agentsview;
  agentsviewSopsFile = ../../../../secrets/agentsview.yaml;
  agentsviewEnvPath = config.sops.templates."agentsview-pg.env".path;
  agentsviewWrappedPackage = pkgs.symlinkJoin {
    name = "agentsview-wrapped";
    paths = [ agentsviewPackage ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/agentsview" \
        --run 'if [ -r "${agentsviewEnvPath}" ]; then set -a; . "${agentsviewEnvPath}"; set +a; fi'
    '';
  };
in
lib.mkIf (noughtyLib.userHasTag "developer") {
  sops.secrets.AGENTSVIEW_PG_URL = {
    sopsFile = agentsviewSopsFile;
    mode = "0400";
  };

  sops.templates."agentsview-pg.env" = {
    content = ''
      AGENTSVIEW_PG_URL=${config.sops.placeholder.AGENTSVIEW_PG_URL}
      AGENTSVIEW_PG_SCHEMA=agentsview
      AGENTSVIEW_PG_MACHINE=${host.name}
      AGENTSVIEW_DISABLE_UPDATE_CHECK=1
    '';
    mode = "0400";
  };

  home.packages = [
    agentsviewWrappedPackage
  ];

  systemd.user.services.agentsview-pg-push = lib.mkIf host.is.linux {
    Unit = {
      Description = "Push local AgentsView data to PostgreSQL";
      After = [
        "sops-nix.service"
      ];
      Wants = [
        "sops-nix.service"
      ];
    };

    Service = {
      Type = "exec";
      EnvironmentFile = config.sops.templates."agentsview-pg.env".path;
      ExecStart = "${agentsviewPackage}/bin/agentsview pg push";
    };
  };

  systemd.user.timers.agentsview-pg-push = lib.mkIf host.is.linux {
    Unit.Description = "Push local AgentsView data to PostgreSQL on a schedule";

    Timer = {
      OnBootSec = "5m";
      OnUnitActiveSec = "30m";
      RandomizedDelaySec = "10m";
      Persistent = true;
      Unit = "agentsview-pg-push.service";
    };

    Install.WantedBy = [
      "timers.target"
    ];
  };
}
