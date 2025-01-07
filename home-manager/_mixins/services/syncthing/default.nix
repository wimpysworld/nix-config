{
  config,
  hostname,
  isLima,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (lib.elem username installFor && !isLima) {
  home = {
    file."/Syncthing/.keep".text = "";
    packages = with pkgs; [ stc-cli ];
  };
  programs.fish.shellAliases = {
    stc = "${pkgs.stc-cli}/bin/stc -homedir \"${config.home.homeDirectory}/Syncthing/Devices/${hostname}\"";
  };
  services.syncthing = {
    enable = true;
    extraOptions = [
      "--config=${config.home.homeDirectory}/Syncthing/Devices/${hostname}"
      "--data=${config.home.homeDirectory}/Syncthing/DB/${hostname}"
      "--no-default-folder"
      "--no-browser"
    ];
    tray = lib.mkIf isWorkstation {
      enable = isLinux;
      package = pkgs.syncthingtray;
    };
  };

  sops = {
    # sops-nix options: https://dl.thalheim.io/
    secrets = {
      syncthing_apikey = { };
      syncthing_user = { };
      syncthing_pass = { };
    };
  };

  # Workaround for Failed to restart syncthingtray.service: Unit tray.target not found.
  # - https://github.com/nix-community/home-manager/issues/2064
  systemd = lib.mkIf isLinux {
    user.targets.tray = lib.mkIf isWorkstation {
      Unit = {
        Description = "Home Manager System Tray";
        Wants = [ "graphical-session-pre.target" ];
      };
    };
    user.services.syncthingtray = {
      Service.ExecStart = lib.mkForce "${pkgs.syncthingtray}/bin/syncthingtray --wait";
    };
  };
}
