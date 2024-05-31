{ config, desktop, hostname, inputs, lib, modulesPath, outputs, pkgs, platform, stateVersion, username, ... }:
let
  notVM = if (hostname == "minimech" || hostname == "scrubber" || builtins.substring 0 5 hostname == "lima-") then false else true;
  # Create some variable to control what doesn't get installed/enabled
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
  isWorkstation = if (desktop != null) then true else false;
  hasNvidia = lib.elem "nvidia" config.services.xserver.videoDrivers;
  # Firewall configuration variable for syncthing
  syncthing = {
    hosts = [
      "phasma"
      "sidious"
      "tanis"
      "vader"
    ];
    tcpPorts = [ 22000 ];
    udpPorts = [ 22000 21027 ];
  };
in
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.nix-index-database.nixosModules.nix-index
    inputs.nix-snapd.nixosModules.default
    inputs.sops-nix.nixosModules.sops
    (modulesPath + "/installer/scan/not-detected.nix")
    ./${hostname}
    ./_mixins/configs
    ./_mixins/users
  ] ++ lib.optional (isWorkstation) ./_mixins/desktop;

  boot = {
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelModules = [ "vhost_vsock" ];
    kernelParams = [
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
    kernelPackages = pkgs.linuxPackages_latest;
    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      # Keep zram swap (lz4) latency in check
      "vm.page-cluster" = 1;
    };
    # Only enable the systemd-boot on installs, not live media (.ISO images)
    loader = lib.mkIf (isInstall) {
      efi.canTouchEfiVariables = true;
      systemd-boot.configurationLimit = 10;
      systemd-boot.consoleMode = "max";
      systemd-boot.enable = true;
      systemd-boot.memtest86.enable = true;
      timeout = 10;
    };
  };

  console = {
    font = "${pkgs.tamzen}/share/consolefonts/TamzenForPowerline10x20.psf";
    keyMap = "uk";
    packages = with pkgs; [ tamzen ];
  };

  i18n = {
    defaultLocale = "en_GB.utf8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_GB.utf8";
      LC_IDENTIFICATION = "en_GB.utf8";
      LC_MEASUREMENT = "en_GB.utf8";
      LC_MONETARY = "en_GB.utf8";
      LC_NAME = "en_GB.utf8";
      LC_NUMERIC = "en_GB.utf8";
      LC_PAPER = "en_GB.utf8";
      LC_TELEPHONE = "en_GB.utf8";
      LC_TIME = "en_GB.utf8";
    };
  };
  services.xserver.layout = "gb";
  time.timeZone = "Europe/London";

  # Only install the docs I use
  documentation.enable = true;
  documentation.nixos.enable = false;
  documentation.man.enable = true;
  documentation.info.enable = false;
  documentation.doc.enable = false;

  environment = {
    # Eject nano and perl from the system
    defaultPackages = with pkgs; lib.mkForce [
      coreutils-full
      micro
    ];

    systemPackages = with pkgs; [
      git
    ] ++ lib.optionals (isInstall) [
      inputs.fh.packages.${platform}.default
      inputs.nixos-needtoreboot.packages.${platform}.default
      clinfo
      distrobox
      flyctl
      fuse-overlayfs
      libva-utils
      nix-output-monitor
      nvd
      nvme-cli
      #https://nixos.wiki/wiki/Podman
      podman-compose
      podman-tui
      podman
      smartmontools
      sops
      ssh-to-age
    ] ++ lib.optionals (isInstall && isWorkstation) [
      pods
    ] ++ lib.optionals (isInstall && isWorkstation && notVM) [
      quickemu
    ] ++ lib.optionals (isInstall && hasNvidia) [
      nvtopPackages.full
      vdpauinfo
    ]  ++ lib.optionals (isInstall && !hasNvidia) [
      nvtopPackages.amd
    ];

    variables = {
      EDITOR = "micro";
      SYSTEMD_EDITOR = "micro";
      VISUAL = "micro";
    };
  };

  hardware = {
    # https://nixos.wiki/wiki/Bluetooth
    bluetooth = {
      enable = true;
      package = pkgs.bluez;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
      };
    };
  };

  # Use passed hostname to configure basic networking
  networking = {
    extraHosts = ''
      192.168.2.1     router
      192.168.2.6     vader-wifi vader
      192.168.2.7     vader-lan
      192.168.2.11    printer
      192.168.2.15	  nuc
      192.168.2.17    skull
      192.168.2.20	  keylight-light key-left Elgato_Key_Light_Air_DAD4
      192.168.2.21    keylight-right key-right Elgato_Key_Light_Air_EEE9
      192.168.2.23    moodlamp
      192.168.2.30    chimeraos-lan
      192.168.2.31	  chimeraos-wifi chimeraos
      192.168.2.58    vonage Vonage-HT801
      192.168.2.184   lametric LaMetric-LM2144
      192.168.2.250   hue-bridge
    '';
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ]
        ++ lib.optionals (builtins.elem hostname syncthing.hosts) syncthing.tcpPorts;
      allowedUDPPorts = [ ]
        ++ lib.optionals (builtins.elem hostname syncthing.hosts) syncthing.udpPorts;
      trustedInterfaces = lib.mkIf (isInstall) [ "lxdbr0" ];
    };
    hostName = hostname;
    useDHCP = lib.mkDefault true;
  };

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
      # Add overlays exported from other flakes:
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  nix = {
    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    # This will additionally add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    optimise.automatic = true;
    package = lib.mkIf (isInstall) pkgs.unstable.nix;
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      warn-dirty = false;
    };
  };
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";

  programs = {
    command-not-found.enable = false;
    dconf.enable = true;
    fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_cursor_default block blink
        set fish_cursor_insert line blink
        set fish_cursor_replace_one underscore blink
        set fish_cursor_visual block
        set -U fish_color_autosuggestion brblack
        set -U fish_color_cancel -r
        set -U fish_color_command green
        set -U fish_color_comment brblack
        set -U fish_color_cwd brgreen
        set -U fish_color_cwd_root brred
        set -U fish_color_end brmagenta
        set -U fish_color_error red
        set -U fish_color_escape brcyan
        set -U fish_color_history_current --bold
        set -U fish_color_host normal
        set -U fish_color_match --background=brblue
        set -U fish_color_normal normal
        set -U fish_color_operator cyan
        set -U fish_color_param blue
        set -U fish_color_quote yellow
        set -U fish_color_redirection magenta
        set -U fish_color_search_match bryellow '--background=brblack'
        set -U fish_color_selection white --bold '--background=brblack'
        set -U fish_color_status red
        set -U fish_color_user brwhite
        set -U fish_color_valid_path --underline
        set -U fish_pager_color_completion normal
        set -U fish_pager_color_description yellow
        set -U fish_pager_color_prefix white --bold --underline
        set -U fish_pager_color_progress brwhite '--background=cyan'
      '';
      shellAbbrs = lib.mkIf (isInstall) {
        captive-portal = "${pkgs.xdg-utils}/bin/xdg-open http://$(${pkgs.iproute2}/bin/ip --oneline route get 1.1.1.1 | ${pkgs.gawk}/bin/awk '{print $3}')";
      };
      shellAliases = {
        nano = "micro";
      };
    };
    nano.enable = lib.mkDefault false;
    nh = {
      clean = {
        enable = true;
        extraArgs = "--keep-since 10d --keep 5";
      };
      enable = true;
      flake = "/home/${username}/Zero/nix-config";
    };
    nix-index-database.comma.enable = isInstall;
    nix-ld = lib.mkIf (isInstall) {
      enable = true;
      libraries = with pkgs; [
      # Add any missing dynamic libraries for unpackaged
      # programs here, NOT in environment.systemPackages
      ];
    };
    ssh.startAgent = true;
  };

  services = {
    avahi = {
      enable = true;
      nssmdns = true;
      # Only open the avahi firewall ports on servers
      openFirewall = isWorkstation;
      publish = {
        addresses = true;
      	enable = true;
      	workstation = isWorkstation;
      };
    };
    fwupd.enable = isInstall;
    hardware.bolt.enable = true;
    homepage-dashboard = {
      enable = isInstall;
      bookmarks = [
        {
        Links = [
          {
            GitHub = [
              {
                abbr = "GH";
                href = "https://github.com/flexiondotorg";
                icon = "github-light.png";
              }
            ];
          }
          {
            GitLab = [
              {
                abbr = "GL";
                href = "https://gitlab.com";
                icon = "gitlab.png";
              }
            ];
          }
          {
            FlakeHub = [
              {
                abbr = "FH";
                href = "https://flakehub.com";
                icon = "https://flakehub.com/favicon.png";
              }
            ];
          }
          {
            Launchpad = [
              {
                abbr = "LP";
                href = "https://launchpad.net/~flexiondotorg";
                icon = "https://launchpad.net/@@/favicon-32x32.png?v=2022";
              }
            ];
          }
          {
            "NixOS Discourse" = [
              {
                abbr = "ND";
                href = "https://discourse.nixos.org";
                icon = "https://discourse.nixos.org/uploads/default/original/2X/c/cb4fe584627b37e7c1d5424e9cec0bb30fdb6c4d.png";
              }
            ];
          }
          {
            "Nixpkgs" = [
              {
                abbr = "NP";
                href = "https://github.com/NixOS/nixpkgs";
                icon = "https://avatars.githubusercontent.com/u/487568?s=48&v=4";
              }
            ];
          }
          {
            "NixOS Search" = [
              {
                abbr = "NS";
                href = "https://search.nixos.org";
                icon = "https://search.nixos.org/images/nix-logo.png";
              }
            ];
          }
          {
            "NixOS Wiki" = [
              {
                abbr = "NW";
                href = "https://wiki.nixos.org";
                icon = "https://wiki.nixos.org/nixos.png";
              }
            ];
          }
          {
            Mastodon = [
              {
                abbr = "MD";
                href = "https://fosstodon.org/deck/@wimpy";
                icon = "mastodon.png";
              }
            ];
          }
          {
            Bluesky = [
              {
                abbr = "BS";
                href = "https://bsky.app/notifications";
                icon = "https://bsky.app/static/favicon-32x32.png";
              }
            ];
          }
          {
            Instagram = [
              {
                abbr = "IG";
                href = "https://www.instagram.com/";
                icon = "instagram.png";
              }
            ];
          }
          {
            X = [
              {
                abbr = "X";
                href = "https://x.com/flexiondotorg";
                icon = "x-light.png";
              }
            ];
          }
          {
            Amazon = [
              {
                abbr = "AZ";
                href = "https://www.amazon.co.uk/";
                icon = "amazon-light.png";
              }
            ];
          }
          {
            eBay = [
              {
                abbr = "EB";
                href = "https://www.ebay.co.uk";
                icon = "ebay.png";
              }
            ];
          }
          {
            Ocado = [
              {
                abbr = "OC";
                href = "https://www.ocado.com/";
                icon = "https://www.ocado.com/webshop/static/images/7.4.99/favicon.png";
              }
            ];
          }
          {
            Scan = [
              {
                abbr = "SC";
                href = "https://scan.co.uk";
                icon = "https://scan.co.uk/content/images/logo-192x192.png";
              }
            ];
          }
          {
            ChatGPT = [
              {
                abbr = "AI";
                href = "https://chatgpt.com/";
                icon = "https://cdn.oaistatic.com/_next/static/media/favicon-32x32.630a2b99.png";
              }
            ];
          }
          {
            Calendar = [
              {
                abbr = "CA";
                href = "https://calendar.google.com";
                icon = "https://ssl.gstatic.com/calendar/images/dynamiclogo_2020q4/calendar_31_2x.png";
              }
            ];
          }
          {
            Gmail = [
              {
                abbr = "GM";
                href = "https://mail.google.com";
                icon = "gmail.png";
              }
            ];
          }
          {
            Notion = [
              {
                abbr = "NT";
                href = "https://notion.so";
                icon = "notion.png";
              }
            ];
          }
        ];
        }
      ];
      services = [
        {
          "Hardware" = [
            {
              "Scrutiny" = {
                description = "Scrutiny";
                href = "http://localhost:8080";
              };
            }
          ];
        }
        {
          "Services" = [
            {
              "Syncthing" = {
                description = "Syncthing";
                href = "http://localhost:8384";
              };
            }
          ];
        }
      ];
      settings = {
        background = "https://raw.githubusercontent.com/wimpysworld/nix-config/main/nixos/_mixins/configs/backgrounds/DeterminateColorway-2560x1440.png";
        color = "zinc";
        favicon = "https://wimpysworld.com/favicon.ico";
        hideVersion = true;
        layout = {
          Links = {
            style = "row";
            columns = 4;
          };
        };
        showStats = true;
        title = "Wimpy's Dashboard";
      };
      widgets = [
        {
          search = {
            provider = "custom";
            target = "_blank";
            url = "https://kagi.com/search?q=";
          };
        }
        {
          resources = {
            label = "system";
            cpu = true;
            memory = true;
          };
        }
        {
          resources = {
            label = "storage";
            disk = [ "/" "/home"];
          };
        }
        {
          openmeteo = {
            label = "Weather";
            latitude = "51.254383";
            longitude = "-0.939525";
            timezone = "Europe/London";
            units = "metric";
          };
        }
      ];
    };
    kmscon = lib.mkIf (isInstall) {
      enable = true;
      hwRender = true;
      fonts = [{
        name = "FiraCode Nerd Font Mono";
        package = pkgs.nerdfonts.override { fonts = [ "FiraCode" ]; };
      }];
      extraConfig = ''
        font-size=14
        xkb-layout=gb
      '';
    };
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = lib.mkDefault "no";
      };
    };
    scrutiny = {
      enable = isInstall;
      collector.enable = false;
    };
    smartd.enable = isInstall;
    snap.enable = isInstall;
    sshguard = {
      enable = true;
      whitelist = [
        "192.168.2.0/24"
        "192.168.192.0/24"
        "62.31.16.154"
        "80.209.186.67"
      ];
    };
  };

  sops = lib.mkIf (isInstall) {
    age = {
      keyFile = "/home/${username}/.config/sops/age/keys.txt";
      generateKey = false;
    };
    defaultSopsFile = ../secrets/secrets.yaml;
    # sops-nix options: https://dl.thalheim.io/
    secrets.test-key = {};
  };

  # Enable Multi-Gen LRU:
  # - https://docs.kernel.org/next/admin-guide/mm/multigen_lru.html
  # - Inspired by: https://github.com/hakavlad/mg-lru-helper
  systemd.services."mglru" = {
    enable = true;
    wantedBy = ["basic.target"];
    script = ''
      ${pkgs.coreutils-full}/bin/echo 1000 > /sys/kernel/mm/lru_gen/min_ttl_ms
    '';
    serviceConfig = {
      Type = "oneshot";
    };
    unitConfig = {
      ConditionPathExists = "/sys/kernel/mm/lru_gen/enabled";
      Description = "Configure Enable Multi-Gen LRU";
    };
  };

  # Disable hiberate and hybrid-sleep when using zram.
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;
  # Enable zram
  # - https://github.com/ecdye/zram-config/blob/main/README.md#performance
  # - https://www.reddit.com/r/Fedora/comments/mzun99/new_zram_tuning_benchmarks/
  # - https://linuxreviews.org/Zram
  zramSwap = {
    algorithm = "lz4";
    enable = true;
  };

  systemd.tmpfiles.rules = [
    "d /nix/var/nix/profiles/per-user/${username} 0755 ${username} root"
  ];

  system = {
    nixos.label = lib.mkIf (isInstall) "-";
    stateVersion = stateVersion;
  };

  virtualisation = lib.mkIf (isInstall) {
    lxd = {
      enable = true;
    };
    podman = {
      defaultNetwork.settings = {
        dns_enabled = true;
      };
      dockerCompat = true;
      dockerSocket.enable = true;
      enable = true;
      enableNvidia = hasNvidia;
    };
    spiceUSBRedirection.enable = true;
  };
}
