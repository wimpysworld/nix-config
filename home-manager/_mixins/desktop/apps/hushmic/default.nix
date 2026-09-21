{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  system = pkgs.stdenv.hostPlatform.system;
  hushmicPackage = import ./package.nix { inherit inputs lib pkgs; };
  supported = hushmicPackage != null;
  sessionTarget = config.wayland.systemd.target;
  initialMic =
    if
      lib.elem host.name [
        "skrye"
        "zannah"
      ]
    then
      "alsa_input.usb-Solid_State_Logic_SSL_2_-00.pro-input-0"
    else
      "default";
in
lib.mkIf (host.is.linux && host.is.workstation) {
  assertions = [
    {
      assertion = supported;
      message = "HushMic does not provide a package for ${system}.";
    }
  ];

  home = {
    packages = lib.optional supported hushmicPackage;
    activation.hushmicInitialConfig = lib.mkIf supported (
      lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "writeBoundary" ] ''
        hushmicConfig=${lib.escapeShellArg "${config.xdg.configHome}/hushmic/config.toml"}
        if [[ ! -e "$hushmicConfig" ]]; then
          run ${lib.getExe hushmicPackage} config set mic ${lib.escapeShellArg initialMic}
          run ${lib.getExe hushmicPackage} config set set_default true
        fi
        run ${lib.getExe hushmicPackage} config set autostart false
        run ${lib.getExe hushmicPackage} config set tray true
      ''
    );
  };

  systemd.user.services.hushmic = lib.mkIf supported {
    Unit = {
      Description = "HushMic noise-suppression virtual microphone";
      Documentation = "https://github.com/Fovty/HushMic";
      After = [
        sessionTarget
        "pipewire.service"
        "wireplumber.service"
      ];
      Wants = [
        "pipewire.service"
        "wireplumber.service"
      ];
      PartOf = [ sessionTarget ];
    };
    Service = {
      ExecStart = "${lib.getExe hushmicPackage} --tray";
      Restart = "on-failure";
      RestartSec = 3;
      KillMode = "mixed";
      TimeoutStopSec = 10;
      Slice = "session.slice";
    };
    Install.WantedBy = [ sessionTarget ];
  };
}
