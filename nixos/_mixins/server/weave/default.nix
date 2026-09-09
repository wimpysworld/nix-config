{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  username = config.noughty.user.name;
  notebookDir = "${config.users.users.${username}.home}/Notes";
  cloudflareSopsFile = ../../../../secrets/cloudflare.yaml;
  hasTunnelToken = lib.hasInfix "\nCLOUDFLARE_TUNNEL_TOKEN_WEAVE:" (
    "\n" + builtins.readFile cloudflareSopsFile
  );
  startWeave = pkgs.writeShellApplication {
    name = "start-weave";
    runtimeInputs = [ pkgs.weave ];
    text = builtins.readFile ./start-weave.sh;
  };
in
lib.mkIf (noughtyLib.isHost [ "revan" ]) {
  systemd.tmpfiles.rules = [
    "d ${notebookDir} 0700 ${username} ${config.users.users.${username}.group} - -"
  ];

  sops.secrets = {
    WEAVE_PASSWORD = {
      sopsFile = ../../../../secrets/weave.yaml;
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "weave.service" ];
    };
    CLOUDFLARE_TUNNEL_TOKEN_WEAVE = lib.mkIf hasTunnelToken {
      sopsFile = cloudflareSopsFile;
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "cloudflared-weave.service" ];
    };
  };

  systemd.services.weave = {
    description = "Weave notebook";
    wantedBy = [ "multi-user.target" ];
    unitConfig.RequiresMountsFor = notebookDir;
    environment = {
      ZK_NOTEBOOK_DIR = notebookDir;
      WEAVE_HOST = "127.0.0.1";
      WEAVE_PORT = "8000";
    };
    serviceConfig = {
      Type = "simple";
      User = username;
      Group = config.users.users.${username}.group;
      WorkingDirectory = notebookDir;
      LoadCredential = "password:${config.sops.secrets.WEAVE_PASSWORD.path}";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${notebookDir}/.zk";
      ExecStart = lib.getExe startWeave;
      Restart = lib.mkDefault "on-failure";
      RestartSec = lib.mkDefault 5;
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = "tmpfs";
      BindPaths = [ notebookDir ];
      ProtectControlGroups = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
        "AF_NETLINK"
      ];
    };
  };

  systemd.services.cloudflared-weave = lib.mkIf hasTunnelToken {
    description = "Cloudflare Tunnel connector for Weave";
    after = [
      "network-online.target"
      "weave.service"
    ];
    wants = [ "network-online.target" ];
    requires = [ "weave.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = lib.concatStringsSep " " [
        (lib.getExe pkgs.cloudflared)
        "tunnel"
        "--no-autoupdate"
        "run"
        "--token-file"
        config.sops.secrets.CLOUDFLARE_TUNNEL_TOKEN_WEAVE.path
      ];
      Restart = lib.mkDefault "always";
      RestartSec = lib.mkDefault 5;
      User = "root";
      Group = "root";
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
