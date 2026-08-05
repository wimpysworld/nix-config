{
  flake,
  homeFlake,
  lib,
}:
let
  root = ../../../../../.;
  targetNames = [
    "bane"
    "ravi"
    "skrye"
    "zannah"
  ];

  expectedHosts = {
    bane = {
      connector = "eDP-1";
      desktopWidth = 2560;
      desktopHeight = 1600;
      monitorX = 0;
      monitorY = 0;
      defaultWidth = 2560;
      defaultHeight = 1600;
      greetdLayout = "";
    };
    ravi = {
      connector = "eDP-1";
      desktopWidth = 2880;
      desktopHeight = 1920;
      monitorX = 0;
      monitorY = 0;
      defaultWidth = 2880;
      defaultHeight = 1920;
      greetdLayout = "";
    };
    skrye = {
      connector = "DP-1";
      desktopWidth = 2560;
      desktopHeight = 2880;
      monitorX = 0;
      monitorY = 0;
      defaultWidth = 2560;
      defaultHeight = 2880;
      greetdLayout = ''
        profile {
            output DP-4 enable mode 2560x2880@60Hz position 2560,0 scale 1.0
            output DP-1 enable mode 2560x2880@60Hz position 0,0 scale 1.0
        }
      '';
    };
    zannah = {
      connector = "DP-1";
      desktopWidth = 3440;
      desktopHeight = 1440;
      monitorX = 0;
      monitorY = 0;
      defaultWidth = 3440;
      defaultHeight = 1440;
      greetdLayout = ''
        profile {
            output HDMI-A-1 enable mode 2560x1600@120Hz position 1920,0 scale 1.25
            output DP-1 enable mode 3440x1440@100Hz position 0,1280 scale 1.0
        }
      '';
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
      (hasLine "damage=gpu" reframeConfig)
      (hasLine "fps=30" reframeConfig)
      (hasLine "ip=127.0.0.1" reframeConfig)
      (hasLine "port=5933" reframeConfig)
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
      (config.environment.etc."kanshi/regreet".text == expected.greetdLayout)
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

  untaggedConfig = configFor "tanis";
  untaggedHomeConfig = homeConfigFor "tanis";
  untaggedCaddy =
    untaggedConfig.services.caddy.virtualHosts."tanis.${untaggedConfig.noughty.network.tailNet}".extraConfig;
  reframePackage = (configFor "bane").services.reframe.package;
  autostartCheck = flake.nixosConfigurations.bane.pkgs.runCommand "reframe-no-autostart" { } ''
    test ! -e ${reframePackage}/etc/xdg/autostart/reframe-session.desktop
    grep -qx 'User=reframe' ${reframePackage}/lib/systemd/system/reframe-server@.service
    ! grep -q '^User=' ${reframePackage}/lib/systemd/system/reframe-streamer@.service
    ! grep -Eq 'CAP_DAC_OVERRIDE|CAP_DAC_READ_SEARCH' ${reframePackage}/lib/systemd/system/reframe-streamer@.service
    touch "$out"
  '';
in
assert lib.all targetPasses targetNames;
assert lib.all homePasses (targetNames ++ [ "tanis" ]);
assert lib.all sessionPasses targetNames;
assert !(builtins.elem "reframe" untaggedConfig.noughty.host.tags);
assert !untaggedConfig.services.reframe.enable;
assert !(builtins.elem "uinput" untaggedConfig.boot.kernelModules);
assert !(untaggedConfig.sops.templates ? reframe-main);
assert !(untaggedConfig.systemd.services ? reframe-websockify);
assert !(untaggedHomeConfig.systemd.user.services ? reframe-session);
assert !(lib.hasInfix "/novnc" untaggedCaddy);
assert !(builtins.pathExists (root + "/home-manager/_mixins/services/wayvnc/default.nix"));
assert !(builtins.pathExists (root + "/home-manager/_mixins/services/wayvnc/README.md"));
autostartCheck
