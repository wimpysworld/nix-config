{
  config,
  pkgs,
  hostname,
  lib,
  ...
}:
with lib;
let
  # Declare which hosts have AV scanning enabled.
  installOn = [
    "phasma"
    "vader"
  ];
  sus-user-dirs = [ "Downloads" ];
  all-normal-users = attrsets.filterAttrs (_username: config: config.isNormalUser) config.users.users;
  all-sus-dirs = builtins.concatMap (
    dir: attrsets.mapAttrsToList (_username: config: config.home + "/" + dir) all-normal-users
  ) sus-user-dirs;
  all-system-folders = [
    "/boot"
    "/etc"
    "/nix"
    "/root"
    "/usr"
  ];
  notify-all-users = pkgs.writeScript "notify-all-users-of-sus-file" ''
    #!/usr/bin/env bash
    ALERT="Signature detected by clamav: $CLAM_VIRUSEVENT_VIRUSNAME in $CLAM_VIRUSEVENT_FILENAME"
    # Send an alert to all graphical users.
    for ADDRESS in /run/user/*; do
        USERID=''${ADDRESS#/run/user/}
       /run/wrappers/bin/sudo -u "#$USERID" DBUS_SESSION_BUS_ADDRESS="unix:path=$ADDRESS/bus" ${pkgs.notify-desktop}/bin/notify-desktop -i dialog-warning "Sus file" "$ALERT"
    done
  '';
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  security.sudo = {
    extraConfig = ''
      clamav ALL = (ALL) NOPASSWD: SETENV: ${pkgs.notify-desktop}/bin/notify-desktop
    '';
  };

  services = {
    clamav = {
      daemon = {
        enable = true;
        settings = {
          ConcurrentDatabaseReload = false;
          OnAccessIncludePath = all-sus-dirs;
          OnAccessPrevention = false;
          OnAccessExtraScanning = true;
          OnAccessExcludeUname = "clamav";
          VirusEvent = "${notify-all-users}";
          User = "clamav";
        };
      };
      updater = {
        enable = true;
        interval = "daily";
        frequency = 2;
      };
    };
  };

  systemd.services.clamav-clamonacc = {
    description = "ClamAV daemon (clamonacc)";
    after = [ "clamav-freshclam.service" ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [ "/etc/clamav/clamd.conf" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.systemd}/bin/systemd-cat --identifier=av-scan ${pkgs.clamav}/bin/clamonacc -F --fdpass";
      PrivateTmp = "yes";
      PrivateDevices = "yes";
      PrivateNetwork = "yes";
    };
  };

  #systemd.timers.av-user-scan = {
  #  description = "scan normal user directories for suspect files";
  #  wantedBy = [ "timers.target" ];
  #  timerConfig = {
  #    OnCalendar = "weekly";
  #    Unit = "av-user-scan.service";
  #  };
  #};

  #systemd.services.av-user-scan = {
  #  description = "scan normal user directories for suspect files";
  #  after = [ "multi-user.target" ];
  #  serviceConfig = {
  #    Type = "oneshot";
  #    ExecStart = "${pkgs.systemd}/bin/systemd-cat --identifier=av-scan ${pkgs.clamav}/bin/clamdscan --quiet --recursive --fdpass ${toString all-user-folders}";
  #  };
  #};

  systemd.timers.av-all-scan = {
    description = "scan all directories for suspect files";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "monthly";
      Unit = "av-all-scan.service";
    };
  };

  systemd.services.av-all-scan = {
    description = "scan all directories for suspect files";
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''
        ${pkgs.systemd}/bin/systemd-cat --identifier=av-scan ${pkgs.clamav}/bin/clamdscan --quiet --recursive --fdpass ${toString all-system-folders}
      '';
    };
  };
}
