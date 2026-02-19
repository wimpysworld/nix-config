# System registry - central definition of all systems and their properties
#
# Canonical tag vocabulary:
#   Host tags: streamstation, trackball, streamdeck, pci-hdmi-capture, thinkpad, policy, steamdeck, lima, wsl, iso
#   User tags: developer, admin, family
#
# Registry fields:
#   kind       - required: "computer", "server", "vm", "container"
#   platform   - required: "x86_64-linux", "aarch64-darwin", etc.
#   formFactor - optional: "laptop", "desktop", "handheld", "tablet", "phone"
#   desktop    - optional: derived from kind + platform if omitted
#   username   - optional: defaults to "martin"
#   gpu        - optional: { vendors = [ "nvidia" "amd" "intel" "apple" ]; compute = { vendor = "nvidia"; vram = 24; }; }
#   tags       - optional: [ "streamstation" "thinkpad" "inference" "iso" ... ]
{

  # Linux workstations
  # desktop defaults to "hyprland" (kind = "computer", linux platform)
  # username defaults to "martin"
  vader = {
    kind = "computer";
    platform = "x86_64-linux";
    formFactor = "desktop";
    gpu = {
      vendors = [
        "amd"
        "nvidia"
      ];
      compute = {
        vendor = "nvidia";
        vram = 16;
      };
    };
    tags = [
      "streamstation"
      "trackball"
      "streamdeck"
      "pci-hdmi-capture"
      "inference"
    ];
    displays = [
      {
        output = "DP-1";
        width = 2560;
        height = 2880;
        primary = true;
        workspaces = [
          1
          2
          7
          8
          9
        ];
      }
      {
        output = "DP-2";
        width = 2560;
        height = 2880;
        workspaces = [
          3
          4
          5
          6
        ];
      }
      {
        output = "DP-3";
        width = 1920;
        height = 1080;
        workspaces = [ 10 ];
      }
    ];
  };
  phasma = {
    kind = "computer";
    platform = "x86_64-linux";
    formFactor = "desktop";
    gpu = {
      vendors = [
        "amd"
        "nvidia"
      ];
      compute = {
        vendor = "nvidia";
        vram = 16;
      };
    };
    tags = [
      "streamstation"
      "trackball"
      "streamdeck"
      "pci-hdmi-capture"
      "inference"
    ];
    displays = [
      {
        output = "DP-1";
        width = 3440;
        height = 1440;
        refresh = 100;
        primary = true;
        workspaces = [
          1
          2
          3
          4
          5
          6
          7
          8
        ];
      }
      {
        output = "HDMI-A-1";
        width = 2560;
        height = 1600;
        refresh = 120;
        scale = 1.25;
        workspaces = [ 9 ];
      }
      {
        output = "DP-2";
        width = 1920;
        height = 1080;
        workspaces = [ 10 ];
      }
    ];
  };
  bane = {
    kind = "computer";
    platform = "x86_64-linux";
    formFactor = "laptop";
    gpu.vendors = [ "amd" ];
    tags = [ "policy" ];
    displays = [
      {
        output = "eDP-1";
        width = 2560;
        height = 1600;
        primary = true;
        workspaces = [
          1
          2
          3
          4
          5
          6
          7
          8
        ];
      }
    ];
  };
  tanis = {
    kind = "computer";
    platform = "x86_64-linux";
    formFactor = "laptop";
    gpu.vendors = [ "amd" ];
    tags = [ "thinkpad" ];
    displays = [
      {
        output = "eDP-1";
        width = 1920;
        height = 1200;
        primary = true;
        workspaces = [
          1
          2
          3
          4
          5
          6
          7
          8
        ];
      }
    ];
  };
  shaa = {
    kind = "computer";
    platform = "x86_64-linux";
    formFactor = "laptop";
    gpu.vendors = [ "amd" ];
    tags = [ "thinkpad" ];
    displays = [
      {
        output = "eDP-1";
        width = 1920;
        height = 1080;
        primary = true;
        workspaces = [
          1
          2
          3
          4
          5
          6
          7
          8
        ];
      }
    ];
  };
  atrius = {
    kind = "computer";
    platform = "x86_64-linux";
    formFactor = "laptop";
    gpu.vendors = [ "amd" ];
    tags = [ "thinkpad" ];
    displays = [
      {
        output = "eDP-1";
        width = 1920;
        height = 1080;
        primary = true;
        workspaces = [
          1
          2
          3
          4
          5
          6
          7
          8
        ];
      }
    ];
  };
  sidious = {
    kind = "computer";
    platform = "x86_64-linux";
    formFactor = "laptop";
    gpu = {
      vendors = [
        "intel"
        "nvidia"
      ];
      compute = {
        vendor = "nvidia";
        vram = 4;
      };
    };
    tags = [ "thinkpad" ];
    displays = [
      {
        output = "eDP-1";
        width = 3840;
        height = 2160;
        scale = 2.0;
        primary = true;
        workspaces = [
          1
          2
          3
          4
          5
          6
          7
          8
        ];
      }
    ];
  };
  felkor = {
    kind = "computer";
    platform = "x86_64-linux";
    formFactor = "laptop";
    gpu.vendors = [ "amd" ];
    tags = [ "thinkpad" ];
    displays = [
      {
        output = "eDP-1";
        width = 1920;
        height = 1200;
        primary = true;
        workspaces = [
          1
          2
          3
          4
          5
          6
          7
          8
        ];
      }
    ];
  };

  # Gaming - non-standard username and desktop, so both explicit
  steamdeck = {
    kind = "computer";
    platform = "x86_64-linux";
    gpu.vendors = [ "amd" ];
    formFactor = "handheld";
    username = "deck";
    desktop = "gamescope";
    tags = [ "steamdeck" ];
  };

  # Servers - desktop = null from kind = "server"
  malak = {
    kind = "server";
    platform = "x86_64-linux";
    gpu.vendors = [ "intel" ];
  };
  maul = {
    kind = "server";
    platform = "x86_64-linux";
    gpu = {
      vendors = [ "nvidia" ];
      compute = {
        vendor = "nvidia";
        vram = 24;
      };
    };
    tags = [ "inference" ];
  };
  revan = {
    kind = "server";
    platform = "x86_64-linux";
    gpu = {
      vendors = [
        "intel"
        "nvidia"
      ];
      compute = {
        vendor = "nvidia";
        vram = 8;
      };
    };
  };

  # Linux VMs
  crawler = {
    kind = "vm";
    platform = "x86_64-linux";
  };
  dagger = {
    kind = "vm";
    platform = "x86_64-linux";
    desktop = "hyprland";
  };

  # Lima VMs (Home Manager only; tag drives module selection)
  blackace = {
    kind = "vm";
    platform = "x86_64-linux";
    tags = [ "lima" ];
  };
  defender = {
    kind = "vm";
    platform = "x86_64-linux";
    tags = [ "lima" ];
  };
  fighter = {
    kind = "vm";
    platform = "x86_64-linux";
    tags = [ "lima" ];
  };

  # WSL (Home Manager only; tag drives module selection)
  palpatine = {
    kind = "vm";
    platform = "x86_64-linux";
    tags = [ "wsl" ];
  };

  # Darwin - platform drives isDarwin; desktop defaults to "aqua"
  momin = {
    kind = "computer";
    platform = "aarch64-darwin";
    formFactor = "laptop";
    gpu = {
      vendors = [ "apple" ];
      compute = {
        vendor = "apple";
        vram = 36;
        unified = true;
      };
    };
  };

  # ISO - "iso" tag applies isoDefaults: desktop = null, username = "nixos"
  nihilus = {
    kind = "computer";
    platform = "x86_64-linux";
    tags = [ "iso" ];
  };
}
