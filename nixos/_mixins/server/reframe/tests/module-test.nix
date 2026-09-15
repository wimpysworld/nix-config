{
  flake,
  homeFlake,
  lib,
}:
let
  root = ../../../../../.;
  targetNames = [
    "skrye"
    "zannah"
  ];
  untaggedNames = [
    "bane"
    "ravi"
    "tanis"
  ];

  expectedHosts = {
    skrye = {
      connector = "DP-1";
      desktopWidth = 2560;
      desktopHeight = 2880;
      monitorX = 0;
      monitorY = 0;
      defaultWidth = 2560;
      defaultHeight = 2880;
    };
    zannah = {
      connector = "DP-1";
      desktopWidth = 3440;
      desktopHeight = 1440;
      monitorX = 0;
      monitorY = 0;
      defaultWidth = 3440;
      defaultHeight = 1440;
    };
  };

  configFor = name: flake.nixosConfigurations.${name}.config;
  homeConfigFor = name: homeFlake.homeConfigurations."martin@${name}".config;
  hasLine = line: text: builtins.elem line (lib.splitString "\n" text);
  indexOf = needle: text: builtins.stringLength (builtins.head (lib.splitString needle text));

  targetPasses =
    name:
    let
      config = configFor name;
      expected = expectedHosts.${name};
      reframeConfig = config.sops.templates.reframe-main.content;
      passwordLines = lib.filter (lib.hasPrefix "password=") (lib.splitString "\n" reframeConfig);
      secret = config.sops.secrets.reframe-password;
      template = config.sops.templates.reframe-main;
      server = config.systemd.services."reframe-server@main";
      websockify = config.systemd.services.reframe-websockify;
      websockifyConfig = websockify.serviceConfig;
      caddyConfig =
        config.services.caddy.virtualHosts."${name}.${config.noughty.network.tailNet}".extraConfig;
    in
    lib.all (value: value) [
      (builtins.elem "reframe" config.noughty.host.tags)
      config.services.reframe.enable
      (config.services.reframe.configs == { })
      (builtins.elem "uinput" config.boot.kernelModules)
      (builtins.elem "reframe" config.users.users.martin.extraGroups)

      (hasLine "card=card1" reframeConfig)
      (hasLine "connector=${expected.connector}" reframeConfig)
      (hasLine "desktop-width=${toString expected.desktopWidth}" reframeConfig)
      (hasLine "desktop-height=${toString expected.desktopHeight}" reframeConfig)
      (hasLine "monitor-x=${toString expected.monitorX}" reframeConfig)
      (hasLine "monitor-y=${toString expected.monitorY}" reframeConfig)
      (hasLine "default-width=${toString expected.defaultWidth}" reframeConfig)
      (hasLine "default-height=${toString expected.defaultHeight}" reframeConfig)
      (hasLine "resize=true" reframeConfig)
      (hasLine "cursor=true" reframeConfig)
      (hasLine "wakeup=true" reframeConfig)
      (hasLine "wakeup-device=keyboard" reframeConfig)
      (hasLine "damage=gpu" reframeConfig)
      (hasLine "fps=30" reframeConfig)
      (hasLine "ip=127.0.0.1" reframeConfig)
      (hasLine "port=5933" reframeConfig)
      (hasLine "backend=libvncserver" reframeConfig)
      (lib.length passwordLines == 1)
      (lib.hasPrefix "password=<SOPS:" (builtins.head passwordLines))
      (lib.hasSuffix ":PLACEHOLDER>" (builtins.head passwordLines))

      config.sops.useSystemdActivation
      (lib.hasSuffix "/secrets/reframe.yaml" (toString secret.sopsFile))
      (secret.key == "password")
      (secret.owner == "root")
      (secret.group == "root")
      (secret.mode == "0400")
      (template.path == "/etc/reframe/main.conf")
      (template.owner == "reframe")
      (template.group == "root")
      (template.mode == "0440")
      (builtins.elem "sops-install-secrets.service" server.after)
      (builtins.elem "sops-install-secrets.service" server.requires)

      (builtins.elem "reframe-server@main.service" websockify.after)
      (builtins.elem "reframe-server@main.service" websockify.requires)
      (lib.hasSuffix "websockify 127.0.0.1:5900 127.0.0.1:5933" websockifyConfig.ExecStart)
      websockifyConfig.DynamicUser
      (websockifyConfig.AmbientCapabilities == [ "" ])
      (websockifyConfig.CapabilityBoundingSet == [ "" ])
      websockifyConfig.NoNewPrivileges
      websockifyConfig.PrivateTmp
      (websockifyConfig.ProtectSystem == "strict")
      websockifyConfig.ProtectHome
      websockifyConfig.ProtectControlGroups
      websockifyConfig.ProtectKernelLogs
      websockifyConfig.ProtectKernelModules
      websockifyConfig.ProtectKernelTunables
      (websockifyConfig.RestrictAddressFamilies == [ "AF_INET" ])
      (websockifyConfig.IPAddressDeny == "any")
      (websockifyConfig.IPAddressAllow == "localhost")

      config.services.tailscale.enable
      (lib.hasInfix "not remote_ip 100.64.0.0/10 fd7a:115c:a1e0::/48" caddyConfig)
      (lib.hasInfix "respond @notTailscale 403" caddyConfig)
      (lib.hasInfix "reverse_proxy 127.0.0.1:5900" caddyConfig)
      (lib.hasInfix "handle /novnc/websockify" caddyConfig)
      (lib.hasInfix "handle_path /novnc/*" caddyConfig)
      (indexOf "respond @notTailscale 403" caddyConfig < indexOf "redir /novnc " caddyConfig)
      (indexOf "respond @notTailscale 403" caddyConfig < indexOf "redir /syncthing " caddyConfig)
      (indexOf "redir /novnc " caddyConfig < indexOf "handle /novnc/websockify" caddyConfig)
      (indexOf "handle /novnc/websockify" caddyConfig < indexOf "handle_path /novnc/*" caddyConfig)
    ];

  expectedGreeters = {
    skrye = [
      "DP-1"
      "2560"
      "2880"
      "60"
    ];
    zannah = null;
    ravi = [
      "eDP-1"
      "2880"
      "1920"
      "120"
    ];
    bane = [
      "eDP-1"
      "2560"
      "1600"
      "165.000000"
    ];
  };

  greeterPasses =
    name: primaryArgs:
    let
      config = configFor name;
      pkgs = flake.nixosConfigurations.${name}.pkgs;
      wrappers = lib.filter (
        package: (package.name or "") == "regreet-cage"
      ) config.environment.systemPackages;
      wrapper = (builtins.head wrappers).text;
      helper = import ../../../desktop/greeters/regreet-output-setup { inherit pkgs; };
      session = [
        "${pkgs.dbus}/bin/dbus-run-session"
        "${pkgs.regreet}/bin/regreet"
      ];
      command =
        if primaryArgs == null then
          lib.concatStringsSep " " session
        else
          lib.escapeShellArgs ([ "${helper}/bin/regreet-output-setup" ] ++ primaryArgs ++ session);
    in
    lib.all (value: value) [
      (lib.length wrappers == 1)
      (config.services.greetd.settings.default_session.command == "regreet-cage")
      (config.services.greetd.settings.default_session.user == "greeter")
      (builtins.elem "d /var/cache/regreet 0700 greeter greeter - -" config.systemd.tmpfiles.rules)
      (hasLine ''export XDG_CACHE_HOME="/var/cache/regreet"'' wrapper)
      (indexOf ''export XDG_CACHE_HOME="/var/cache/regreet"'' wrapper < indexOf "/bin/cage -d" wrapper)
      (config.noughty.host.display.isMultiMonitor == (primaryArgs != null))
      (hasLine "${pkgs.cage}/bin/cage -d -m last -s -- ${command}" wrapper)
      (!(config.environment.etc ? "kanshi/regreet"))
      (!(lib.hasInfix "kanshi" wrapper))
      (primaryArgs != null || !(lib.hasInfix "regreet-output-setup" wrapper))
    ];

  homePasses =
    name:
    let
      config = homeConfigFor name;
    in
    !config.services.wayvnc.enable
    && !(config.systemd.user.services ? wayvnc)
    && !(builtins.any (
      package: (package.pname or package.name or "") == "wayvnc"
    ) config.home.packages);

  sessionPasses = name: (homeConfigFor name).systemd.user.services ? reframe-session;

  untaggedPasses =
    name:
    let
      config = configFor name;
      homeConfig = homeConfigFor name;
      caddyConfig =
        config.services.caddy.virtualHosts."${name}.${config.noughty.network.tailNet}".extraConfig;
    in
    lib.all (value: value) [
      (!(builtins.elem "reframe" config.noughty.host.tags))
      (!config.services.reframe.enable)
      (!(builtins.elem "uinput" config.boot.kernelModules))
      (!(builtins.elem "reframe" config.users.users.martin.extraGroups))
      (!(config.sops.secrets ? reframe-password))
      (!(config.sops.templates ? reframe-main))
      (!(config.systemd.services ? "reframe-server@main"))
      (!(config.systemd.services ? reframe-websockify))
      (!(homeConfig.systemd.user.services ? reframe-session))
      (!(lib.hasInfix "/novnc" caddyConfig))
    ];

  reframePackage = (configFor "skrye").services.reframe.package;
  autostartCheck = flake.nixosConfigurations.skrye.pkgs.runCommand "reframe-no-autostart" { } ''
    test ! -e ${reframePackage}/etc/xdg/autostart/reframe-session.desktop
    grep -qx 'User=reframe' ${reframePackage}/lib/systemd/system/reframe-server@.service
    ! grep -q '^User=' ${reframePackage}/lib/systemd/system/reframe-streamer@.service
    ! grep -Eq 'CAP_DAC_OVERRIDE|CAP_DAC_READ_SEARCH' ${reframePackage}/lib/systemd/system/reframe-streamer@.service
    touch "$out"
  '';
in
assert lib.all targetPasses targetNames;
assert lib.all (value: value) (lib.mapAttrsToList greeterPasses expectedGreeters);
assert lib.all homePasses (targetNames ++ untaggedNames);
assert lib.all sessionPasses targetNames;
assert lib.all untaggedPasses untaggedNames;
assert !(builtins.pathExists (root + "/home-manager/_mixins/services/wayvnc/default.nix"));
assert !(builtins.pathExists (root + "/home-manager/_mixins/services/wayvnc/README.md"));
assert reframePackage.version == "1.20.1";
autostartCheck
