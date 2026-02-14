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

  # Import Syncthing device and folder definitions
  syncDefs = import ./syncthing-devices.nix;

  # Determine whether this host is a Syncthing cohort member
  isSyncthingHost = builtins.hasAttr hostname syncDefs.devices;

  # Exclude the current host from the devices list
  otherDevices = lib.filterAttrs (name: _: name != hostname) syncDefs.devices;

  # Transform folders: enable only where this host is listed, remove self from devices
  hostFolders = lib.mapAttrs (
    name: folder:
    folder
    // {
      enable = lib.elem hostname folder.devices;
      devices = lib.filter (d: d != hostname) folder.devices;
    }
  ) syncDefs.folders;

  keybasePackages =
    if isWorkstation then
      [
        pkgs.keybase
        pkgs.keybase-gui
      ]
    else
      [ pkgs.keybase ];
in
lib.mkIf (lib.elem username installFor && !isLima) {
  home = lib.mkIf isLinux {
    file."${config.xdg.configHome}/keybase/autostart_created".text = ''
      This file is created the first time Keybase starts, along with
      ~/.config/autostart/keybase_autostart.desktop. As long as this
      file exists, the autostart file won't be automatically recreated.
    '';
    packages = with pkgs; [ stc-cli ] ++ lib.optionals (hostname != "bane") keybasePackages;
  };

  programs.fish.shellAliases = lib.mkIf isLinux {
    stc = "${pkgs.stc-cli}/bin/stc";
  };

  sops.secrets = lib.mkIf isSyncthingHost {
    syncthing_key.sopsFile = ../../../secrets/${hostname}.yaml;
    syncthing_cert.sopsFile = ../../../secrets/${hostname}.yaml;
    pass.sopsFile = ../../../secrets/syncthing.yaml;
    syncthing_apikey = {
      sopsFile = ../../../secrets/syncthing.yaml;
      key = "apikey";
    };
  };

  services = {
    # Keybase is Linux-only (macOS uses Homebrew cask)
    kbfs = lib.mkIf (isLinux && hostname != "bane") {
      enable = true;
      mountPoint = "Keybase";
    };
    keybase = lib.mkIf (isLinux && hostname != "bane") {
      enable = true;
    };
    # Syncthing works on both Linux (systemd) and macOS (launchd)
    syncthing = lib.mkIf isSyncthingHost {
      enable = true;
      cert = config.sops.secrets.syncthing_cert.path;
      key = config.sops.secrets.syncthing_key.path;
      overrideDevices = true;
      overrideFolders = true;
      passwordFile = config.sops.secrets.pass.path;
      settings = {
        devices = otherDevices;
        folders = hostFolders;
        gui = {
          theme = "dark";
          user = username;
        };
        options = {
          localAnnounceEnabled = true;
          relaysEnabled = true;
          startBrowser = false;
          urAccepted = -1;
        };
      };
      # Tray is Linux-only (uses systemd and X11/Wayland tray protocol)
      tray = lib.mkIf (isLinux && isWorkstation) {
        enable = true;
        package = pkgs.syncthingtray;
      };
    };
  };

  # Workaround for Failed to restart syncthingtray.service: Unit tray.target not found.
  # - https://github.com/nix-community/home-manager/issues/2064
  systemd = lib.mkIf (isLinux && isSyncthingHost) {
    user.targets.tray = lib.mkIf isWorkstation {
      Unit = {
        Description = "Home Manager System Tray";
        Wants = [ "graphical-session-pre.target" ];
      };
    };
    user.services.syncthing-init.Service.ExecStartPost =
      let
        setApiKey = pkgs.writeShellScript "syncthing-set-apikey" ''
          APIKEY=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.syncthing_apikey.path})
          CURRENT_KEY=$(${pkgs.libxml2}/bin/xmllint --xpath 'string(configuration/gui/apikey)' "''${XDG_STATE_HOME:-$HOME/.local/state}/syncthing/config.xml")
          ${pkgs.curl}/bin/curl -sSLk \
            -H "X-API-Key: $CURRENT_KEY" \
            -X PATCH \
            -d "{\"apikey\": \"$APIKEY\"}" \
            --retry 5 --retry-delay 2 --retry-all-errors \
            http://127.0.0.1:8384/rest/config/gui
        '';
      in
      "${setApiKey}";
    user.services.syncthingtray = lib.mkIf isWorkstation {
      Service.ExecStart = lib.mkForce "${pkgs.syncthingtray}/bin/syncthingtray --wait";
    };
  };
}
