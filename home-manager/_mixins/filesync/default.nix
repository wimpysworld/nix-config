{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  username = config.noughty.user.name;
  inherit (config.noughty) host;

  # Import Syncthing device and folder definitions
  syncDefs = import ./syncthing-devices.nix;

  # Determine whether this host is a Syncthing cohort member
  isSyncthingHost = builtins.hasAttr host.name syncDefs.devices;

  # Exclude the current host from the devices list
  otherDevices = lib.filterAttrs (name: _: name != host.name) syncDefs.devices;

  # Transform folders: enable only where this host is listed, remove self from devices
  hostFolders = lib.mapAttrs (
    _name: folder:
    folder
    // {
      enable = lib.elem host.name folder.devices;
      devices = lib.filter (d: d != host.name) folder.devices;
    }
  ) syncDefs.folders;

  isKeybaseHost = host.is.linux && host.is.workstation && !(noughtyLib.hostHasTag "cg");

  keybasePackages = [
    pkgs.keybase
    pkgs.keybase-gui
  ];
in
lib.mkIf (noughtyLib.isUser [ "martin" ] && !(noughtyLib.hostHasTag "lima")) {
  home = {
    file = lib.mkIf (host.is.linux && isKeybaseHost) {
      "${config.xdg.configHome}/keybase/autostart_created".text = ''
        This file is created the first time Keybase starts, along with
        ~/.config/autostart/keybase_autostart.desktop. As long as this
        file exists, the autostart file won't be automatically recreated.
      '';
    };
    packages = lib.mkIf host.is.linux (
      lib.optionals isSyncthingHost [ pkgs.stc-cli ] ++ lib.optionals isKeybaseHost keybasePackages
    );

    activation.syncthingNotesIgnore = lib.mkIf (isSyncthingHost && hostFolders.notes.enable) (
      lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "writeBoundary" ] ''
        run ${lib.getExe pkgs.python3} - <<'PY'
        import os
        from pathlib import Path
        import stat
        import tempfile

        path = Path(${builtins.toJSON "${config.home.homeDirectory}/${lib.removePrefix "~/" hostFolders.notes.path}/.stignore"})
        pattern = b"/.zk/notebook.db*\n"
        if path.is_symlink() or (path.exists() and not path.is_file()):
            raise SystemExit(f"Cannot update Syncthing ignores: {path} is not a regular file")
        existing = path.read_bytes() if path.exists() else b""
        if not existing.startswith(pattern):
            path.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".stignore-", delete=False) as output:
                temporary = Path(output.name)
                try:
                    if path.exists():
                        os.fchmod(output.fileno(), stat.S_IMODE(path.stat().st_mode))
                    output.write(pattern + existing)
                    output.close()
                    os.replace(temporary, path)
                finally:
                    temporary.unlink(missing_ok=True)
        PY
      ''
    );
  };

  programs.fish.shellAliases = lib.mkIf (host.is.linux && isSyncthingHost) {
    stc = "${pkgs.stc-cli}/bin/stc";
  };

  sops.secrets = lib.mkIf isSyncthingHost {
    syncthing_key.sopsFile = ../../../secrets/host-${host.name}.yaml;
    syncthing_cert.sopsFile = ../../../secrets/host-${host.name}.yaml;
    pass.sopsFile = ../../../secrets/syncthing.yaml;
    syncthing_apikey = {
      sopsFile = ../../../secrets/syncthing.yaml;
      key = "apikey";
    };
  };

  services = {
    # Keybase is Linux-only (macOS uses Homebrew cask)
    kbfs = lib.mkIf isKeybaseHost {
      enable = true;
      mountPoint = "Keybase";
    };
    keybase = lib.mkIf isKeybaseHost {
      enable = true;
    };
    # Syncthing works on both Linux (systemd) and macOS (launchd)
    syncthing = lib.mkIf isSyncthingHost {
      enable = true;
      cert = config.sops.secrets.syncthing_cert.path;
      key = config.sops.secrets.syncthing_key.path;
      overrideDevices = true;
      overrideFolders = true;
      guiCredentials = {
        inherit username;
        passwordFile = config.sops.secrets.pass.path;
      };
      settings = {
        devices = otherDevices;
        folders = hostFolders;
        gui = {
          theme = "dark";
        };
        options = {
          localAnnounceEnabled = true;
          relaysEnabled = true;
          startBrowser = false;
          urAccepted = -1;
        };
      };
      # Tray is Linux-only (uses systemd and X11/Wayland tray protocol)
      tray = lib.mkIf (host.is.linux && host.is.workstation) {
        enable = true;
        package = pkgs.syncthingtray;
      };
    };
  };

  # Workaround for Failed to restart syncthingtray.service: Unit tray.target not found.
  # - https://github.com/nix-community/home-manager/issues/2064
  systemd = lib.mkIf (host.is.linux && isSyncthingHost) {
    user = {
      targets.tray = lib.mkIf host.is.workstation {
        Unit = {
          Description = "Home Manager System Tray";
          Wants = [ "graphical-session-pre.target" ];
        };
      };

      services = {
        syncthing-init.Service.ExecStartPost =
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

        syncthingtray = lib.mkIf host.is.workstation {
          Service.ExecStart = lib.mkForce "${pkgs.syncthingtray}/bin/syncthingtray --wait";
        };
      };
    };
  };
}
