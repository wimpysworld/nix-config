{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (host.display) primary;

  drmCards = {
    bane = "card1";
    ravi = "card1";
    skrye = "card1";
    zannah = "card1";
  };

in
lib.mkIf (noughtyLib.hostHasTag "reframe") {
  boot.kernelModules = [ "uinput" ];

  services.reframe = {
    enable = true;
    package = pkgs.reframe.overrideAttrs (oldAttrs: {
      # Veila powers displays off while locked and ignores the pointer motion
      # ReFrame injects for wakeup, so add a KEY_WAKEUP press and retry the
      # CRTC lookup while the display wakes.
      patches = (oldAttrs.patches or [ ]) ++ [ ./reframe-wakeup-key.patch ];
      postInstall = (oldAttrs.postInstall or "") + ''
        rm "$out/etc/xdg/autostart/reframe-session.desktop"
      '';
    });
    configs = { };
  };

  sops = {
    useSystemdActivation = true;

    secrets.reframe-password = {
      sopsFile = ../../../../secrets/reframe.yaml;
      key = "password";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    templates.reframe-main = {
      # The compositor maps ReFrame's absolute pointer over the bounding box
      # of the live output layout, and secondary monitors drop off DRM in deep
      # standby, which is the normal state when connecting remotely. Describe
      # the desktop as the primary display alone so pointer mapping is exact
      # in that state; while a secondary display is awake the pointer skews
      # until it sleeps again.
      content = ''
        [reframe]
        card=${drmCards.${host.name}}
        connector=${host.display.primaryOutput}
        rotation=0
        desktop-width=${toString primary.width}
        desktop-height=${toString primary.height}
        monitor-x=0
        monitor-y=0
        default-width=${toString primary.width}
        default-height=${toString primary.height}
        resize=true
        cursor=true
        wakeup=true
        damage=gpu
        fps=30

        [vnc]
        ip=127.0.0.1
        port=5933
        password=${config.sops.placeholder.reframe-password}
        type=libvncserver

        [libvncserver]

        [neatvnc]
        allow-broken-crypto=false
      '';
      path = "/etc/reframe/main.conf";
      owner = "reframe";
      group = "root";
      mode = "0440";
      restartUnits = [
        "reframe-server@main.service"
        "reframe-streamer@main.service"
      ];
    };
  };

  # This shadows the package's relative and incomplete tmpfiles rule.
  environment.etc."tmpfiles.d/reframe-tmpfiles.conf".text = ''
    d /etc/reframe 0750 root reframe - -
  '';

  # Clipboard text synchronisation requires the desktop user to read the
  # session socket in /run/reframe-session, which is owned by the reframe
  # group. The reframe-session user service lives in Home Manager.
  users.users.${config.noughty.user.name}.extraGroups = [ "reframe" ];

  systemd.services = {
    "reframe-server@main" = {
      overrideStrategy = "asDropin";
      after = [ "sops-install-secrets.service" ];
      requires = [ "sops-install-secrets.service" ];
      wantedBy = [ "multi-user.target" ];
      # The server translates VNC keysyms through libxkbcommon, which reads
      # the layout and variant from the environment and falls back to US.
      environment = {
        XKB_DEFAULT_LAYOUT = host.keyboard.layout;
        # The reframe user's home is /var/empty, so give Mesa a writable
        # shader cache to avoid recompiling the damage shaders every start.
        XDG_CACHE_HOME = "/var/cache/reframe-server";
      }
      // lib.optionalAttrs (host.keyboard.variant != "") {
        XKB_DEFAULT_VARIANT = host.keyboard.variant;
      };
      serviceConfig = {
        WorkingDirectory = "/";
        AmbientCapabilities = [ "" ];
        CapabilityBoundingSet = [ "" ];
        CacheDirectory = "reframe-server";
      };
    };

    "reframe-streamer@main" = {
      overrideStrategy = "asDropin";
      after = [ "sops-install-secrets.service" ];
      requires = [ "sops-install-secrets.service" ];
      serviceConfig.WorkingDirectory = "/";
    };
  };
}
