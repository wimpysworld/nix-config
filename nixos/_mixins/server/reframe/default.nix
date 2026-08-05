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

  logicalDisplays = map (display: {
    width = builtins.floor (display.width / display.scale);
    height = builtins.floor (display.height / display.scale);
    inherit (display) position;
  }) host.displays;
  logicalDesktopWidth = lib.foldl' (
    width: display: lib.max width (display.position.x + display.width)
  ) 0 logicalDisplays;
  logicalDesktopHeight = lib.foldl' (
    height: display: lib.max height (display.position.y + display.height)
  ) 0 logicalDisplays;
  # ReFrame combines physical CRTC dimensions with desktop coordinates, so
  # express the logical layout in the primary display's physical coordinate space.
  reframeScale = value: builtins.floor (value * primary.scale);
in
lib.mkIf (noughtyLib.hostHasTag "reframe") {
  boot.kernelModules = [ "uinput" ];

  services.reframe = {
    enable = true;
    package = pkgs.reframe.overrideAttrs (oldAttrs: {
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
      content = ''
        [reframe]
        card=${drmCards.${host.name}}
        connector=${host.display.primaryOutput}
        rotation=0
        desktop-width=${toString (reframeScale logicalDesktopWidth)}
        desktop-height=${toString (reframeScale logicalDesktopHeight)}
        monitor-x=${toString (reframeScale primary.position.x)}
        monitor-y=${toString (reframeScale primary.position.y)}
        default-width=${toString primary.width}
        default-height=${toString primary.height}
        resize=true
        cursor=true
        wakeup=true
        damage=cpu
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

  systemd.services = {
    "reframe-server@main" = {
      overrideStrategy = "asDropin";
      after = [ "sops-install-secrets.service" ];
      requires = [ "sops-install-secrets.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        WorkingDirectory = "/";
        AmbientCapabilities = [ "" ];
        CapabilityBoundingSet = [ "" ];
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
