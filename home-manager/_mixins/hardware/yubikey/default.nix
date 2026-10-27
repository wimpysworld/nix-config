{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  sessionTarget = config.wayland.systemd.target;
in
lib.mkIf (host.is.linux && host.is.workstation) {
  home.packages = with pkgs; [
    yubikey-touch-detector
    yubioath-flutter
  ];

  systemd.user.services.yubikey-touch-detector = lib.mkIf (sessionTarget != "") {
    Unit = {
      Description = "Detects when your YubiKey is waiting for a touch";
      After = [ sessionTarget ];
      PartOf = [ sessionTarget ];
      Requires = [ "yubikey-touch-detector.socket" ];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.yubikey-touch-detector} --libnotify";
      Environment = [ "PATH=${lib.makeBinPath [ pkgs.gnupg ]}" ];
      EnvironmentFile = "-%E/yubikey-touch-detector/service.conf";
    };
    Install = {
      Also = [ "yubikey-touch-detector.socket" ];
      WantedBy = [ sessionTarget ];
    };
  };

  systemd.user.sockets.yubikey-touch-detector = {
    Unit = {
      Description = "Unix socket activation for YubiKey touch detector service";
    };
    Socket = {
      ListenStream = "%t/yubikey-touch-detector.socket";
      RemoveOnStop = true;
    };
    Install = {
      WantedBy = [ "sockets.target" ];
    };
  };
}
