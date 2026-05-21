{
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  agentsviewPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agentsview;
in
lib.mkIf (noughtyLib.hostHasTag "agentsview") {
  # Static system user for the agentsview service. A static UID lets the sops
  # template that holds the PG URL be owned by `agentsview` directly, which is
  # simpler than the LoadCredential dance required by DynamicUser. This also
  # matches the static-user shape of the librechat hardening template the unit
  # below is based on.
  users.users.agentsview = {
    isSystemUser = true;
    group = "agentsview";
    description = "AgentsView read-only PostgreSQL dashboard";
  };
  users.groups.agentsview = { };

  systemd.services.agentsview = {
    description = "AgentsView read-only dashboard (PostgreSQL-backed)";
    after = [
      "postgresql.service"
      "network-online.target"
    ];
    wants = [
      "postgresql.service"
      "network-online.target"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      # AgentsView 0.29.0 takes host/port/base-path as CLI flags only; there
      # is no PG_SERVE / AGENTSVIEW_PORT / AGENTSVIEW_LISTEN env var. The only
      # env var consumed for `pg serve` is AGENTSVIEW_PG_URL, supplied via the
      # sops-templated EnvironmentFile.
      ExecStart = lib.concatStringsSep " " [
        "${agentsviewPackage}/bin/agentsview"
        "pg"
        "serve"
        "--host"
        "127.0.0.1"
        "--port"
        "18080"
        "--base-path"
        "/agentsview"
        "--no-browser"
        "--no-update-check"
      ];
      EnvironmentFile = config.sops.templates."agentsview.env".path;

      User = "agentsview";
      Group = "agentsview";
      StateDirectory = "agentsview";
      StateDirectoryMode = "0750";

      Restart = "on-failure";
      RestartSec = 5;

      # Hardening, copied from the librechat cloudflared-librechat unit
      # (nixos/_mixins/server/librechat/default.nix:212-247).
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectControlGroups = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
    };
  };
}
