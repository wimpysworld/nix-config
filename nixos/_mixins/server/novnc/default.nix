{
  lib,
  noughtyLib,
  pkgs,
  ...
}:
lib.mkIf (noughtyLib.hostHasTag "reframe") {
  systemd.services.reframe-websockify = {
    description = "Loopback WebSocket bridge for ReFrame";
    requires = [ "reframe-server@main.service" ];
    after = [ "reframe-server@main.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.python3Packages.websockify}/bin/websockify 127.0.0.1:5900 127.0.0.1:5933";
      Restart = "on-failure";

      DynamicUser = true;
      AmbientCapabilities = [ "" ];
      CapabilityBoundingSet = [ "" ];
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectControlGroups = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictAddressFamilies = [ "AF_INET" ];
      IPAddressDeny = "any";
      IPAddressAllow = "localhost";
    };
  };
}
