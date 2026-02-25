# Noughty: Centralised system attributes module.
# Declares typed options for host identity, classification, display
# configuration, user identity, and network attributes. Safe to import
# verbatim into NixOS, nix-darwin, and Home Manager.
{
  config,
  lib,
  ...
}:
let
  helpers = import ../noughty-helpers.nix { inherit lib; };

  # Display submodule, shared between noughty.host.displays and
  # noughty.host.display.primary.
  displaySubmodule = lib.types.submodule {
    options = {
      output = lib.mkOption {
        type = lib.types.str;
        description = "Output connector name (e.g. \"DP-1\", \"eDP-1\").";
      };
      width = lib.mkOption {
        type = lib.types.int;
        description = "Horizontal resolution in pixels.";
      };
      height = lib.mkOption {
        type = lib.types.int;
        description = "Vertical resolution in pixels.";
      };
      refresh = lib.mkOption {
        type = lib.types.int;
        default = 60;
        description = "Refresh rate in Hz.";
      };
      scale = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Display scale factor.";
      };
      position = lib.mkOption {
        type = lib.types.submodule {
          options = {
            x = lib.mkOption {
              type = lib.types.int;
              default = 0;
              description = "Horizontal position offset in pixels.";
            };
            y = lib.mkOption {
              type = lib.types.int;
              default = 0;
              description = "Vertical position offset in pixels.";
            };
          };
        };
        default = {
          x = 0;
          y = 0;
        };
        description = "Display position offset.";
      };
      primary = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this is the primary display.";
      };
      workspaces = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [ ];
        description = "Workspace numbers assigned to this display.";
      };
    };
  };

  # Compute the primary display from the displays list.
  primaryDisplay =
    let
      inherit (config.noughty.host) displays;
      primaries = lib.filter (d: d.primary) displays;
    in
    if primaries != [ ] then
      lib.head primaries
    else if displays != [ ] then
      lib.head displays
    else
      null;
in
{
  options.noughty = {

    # ── Host identity and classification ──────────────────────────────

    host = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "localhost";
        description = "Hostname of the managed system.";
      };

      kind = lib.mkOption {
        type = lib.types.enum [
          "computer"
          "server"
          "vm"
          "container"
        ];
        default = "computer";
        description = "Class of host system, independent of OS or use-case.";
      };

      platform = lib.mkOption {
        type = lib.types.str;
        default = "x86_64-linux";
        description = "Architecture string (e.g. \"x86_64-linux\", \"aarch64-darwin\").";
      };

      desktop = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Desktop environment name, or null for headless systems.";
      };

      formFactor = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "laptop"
            "desktop"
            "handheld"
            "tablet"
            "phone"
          ]
        );
        default = null;
        description = "Physical form factor of the host. Null for virtual or headless systems.";
      };

      tags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Freeform tags for host classification (e.g. \"studio\", \"thinkpad\").";
      };

      # ── Derived OS (read-only) ────────────────────────────────────

      os = lib.mkOption {
        type = lib.types.enum [
          "linux"
          "darwin"
        ];
        default = if lib.hasSuffix "-linux" config.noughty.host.platform then "linux" else "darwin";
        description = "OS of the managed system, derived from platform. Never set manually.";
        readOnly = true;
      };

      # ── Derived boolean flags ─────────────────────────────────────

      is = {
        workstation = lib.mkOption {
          type = lib.types.bool;
          default = config.noughty.host.desktop != null;
          description = "Whether this host is a workstation (has a desktop environment).";
        };

        server = lib.mkOption {
          type = lib.types.bool;
          default = config.noughty.host.kind == "server";
          description = "Whether this host is a server.";
        };

        laptop = lib.mkOption {
          type = lib.types.bool;
          default = config.noughty.host.formFactor == "laptop";
          description = "Whether this host is a laptop.";
        };

        iso = lib.mkOption {
          type = lib.types.bool;
          default = lib.elem "iso" config.noughty.host.tags;
          description = "Whether this host is an ISO image build. Derived from the \"iso\" tag.";
          readOnly = true;
        };

        vm = lib.mkOption {
          type = lib.types.bool;
          default = config.noughty.host.kind == "vm";
          description = "Whether this host is a virtual machine.";
        };

        darwin = lib.mkOption {
          type = lib.types.bool;
          default = config.noughty.host.os == "darwin";
          description = "Whether this host runs macOS (Darwin).";
        };

        linux = lib.mkOption {
          type = lib.types.bool;
          default = config.noughty.host.os == "linux";
          description = "Whether this host runs Linux.";
        };
      };

      # ── GPU vendor classification ─────────────────────────────────

      gpu = {
        vendors = lib.mkOption {
          type = lib.types.listOf (
            lib.types.enum [
              "nvidia"
              "amd"
              "intel"
              "apple"
            ]
          );
          default = [ ];
          description = "GPU vendors present in this host.";
        };

        compute = {
          vendor = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "nvidia"
                "amd"
                "intel"
                "apple"
              ]
            );
            default = null;
            description = "GPU vendor used for compute workloads (CUDA/ROCm/etc).";
          };

          vram = lib.mkOption {
            type = lib.types.int;
            default = 0;
            description = ''
              VRAM available on the compute GPU, in GB.
              For discrete GPUs, use the card's VRAM (e.g. 24 for RTX 3090).
              For unified memory (Apple Silicon, AMD Strix Halo), use the
              portion allocatable for GPU compute.
              Zero means no usable GPU memory for compute.
            '';
          };

          unified = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Whether the compute GPU uses unified memory shared with the CPU.
              True for Apple Silicon and AMD Strix Halo. Inference runtimes
              can use more aggressive memory strategies on unified architectures.
            '';
          };

          acceleration = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "cuda"
                "rocm"
                "vulkan"
                "metal"
              ]
            );
            default =
              if config.noughty.host.gpu.compute.vendor == "nvidia" then
                "cuda"
              else if config.noughty.host.gpu.compute.vendor == "amd" then
                "rocm"
              else if config.noughty.host.gpu.compute.vendor == "apple" then
                "metal"
              else
                null;
            description = ''
              GPU acceleration framework for compute workloads.
              Defaults to cuda for NVIDIA, rocm for AMD, metal for Apple, null otherwise.
              Override to vulkan for cross-vendor comparison or fallback.
            '';
          };
        };

        hasNvidia = lib.mkOption {
          type = lib.types.bool;
          default = lib.elem "nvidia" config.noughty.host.gpu.vendors;
          description = "Whether this host has an NVIDIA GPU. Derived from gpu.vendors.";
          readOnly = true;
        };

        hasAmd = lib.mkOption {
          type = lib.types.bool;
          default = lib.elem "amd" config.noughty.host.gpu.vendors;
          description = "Whether this host has an AMD GPU. Derived from gpu.vendors.";
          readOnly = true;
        };

        hasIntel = lib.mkOption {
          type = lib.types.bool;
          default = lib.elem "intel" config.noughty.host.gpu.vendors;
          description = "Whether this host has an Intel GPU. Derived from gpu.vendors.";
          readOnly = true;
        };

        hasApple = lib.mkOption {
          type = lib.types.bool;
          default = lib.elem "apple" config.noughty.host.gpu.vendors;
          description = "Whether this host has an Apple GPU. Derived from gpu.vendors.";
          readOnly = true;
        };

        hasAny = lib.mkOption {
          type = lib.types.bool;
          default = config.noughty.host.gpu.vendors != [ ];
          description = "Whether this host has any GPU. Derived from gpu.vendors.";
          readOnly = true;
        };

        hasCuda = lib.mkOption {
          type = lib.types.bool;
          default = config.noughty.host.gpu.compute.acceleration == "cuda";
          description = "Whether this host has CUDA compute capability. Derived from compute.acceleration.";
          readOnly = true;
        };

        hasROCm = lib.mkOption {
          type = lib.types.bool;
          default = config.noughty.host.gpu.compute.acceleration == "rocm";
          description = "Whether this host has ROCm compute capability. Derived from compute.acceleration.";
          readOnly = true;
        };

        hasMetal = lib.mkOption {
          type = lib.types.bool;
          default = config.noughty.host.gpu.compute.acceleration == "metal";
          description = "Whether this host has Metal compute capability. Derived from compute.acceleration.";
          readOnly = true;
        };
      };

      # ── Display output configuration ──────────────────────────────

      displays = lib.mkOption {
        type = lib.types.listOf displaySubmodule;
        default = [ ];
        description = "Physical display outputs. Set in host-specific modules.";
      };

      # ── Derived display values (all read-only) ────────────────────

      display = {
        primary = lib.mkOption {
          type = lib.types.nullOr lib.types.attrs;
          default = primaryDisplay;
          description = "The primary display attrset, or null if no displays are configured.";
          readOnly = true;
        };

        primaryOutput = lib.mkOption {
          type = lib.types.str;
          default = if primaryDisplay != null then primaryDisplay.output else "";
          description = "Output connector name of the primary display.";
          readOnly = true;
        };

        primaryWidth = lib.mkOption {
          type = lib.types.int;
          default = if primaryDisplay != null then primaryDisplay.width else 0;
          description = "Horizontal resolution of the primary display in pixels.";
          readOnly = true;
        };

        primaryHeight = lib.mkOption {
          type = lib.types.int;
          default = if primaryDisplay != null then primaryDisplay.height else 0;
          description = "Vertical resolution of the primary display in pixels.";
          readOnly = true;
        };

        primaryResolution = lib.mkOption {
          type = lib.types.str;
          default =
            if primaryDisplay != null then
              "${toString primaryDisplay.width}x${toString primaryDisplay.height}"
            else
              "";
          description = "Formatted resolution of the primary display (e.g. \"3440x1440\").";
          readOnly = true;
        };

        primaryOrientation = lib.mkOption {
          type = lib.types.enum [
            "landscape"
            "portrait"
          ];
          default =
            if primaryDisplay != null && primaryDisplay.height > primaryDisplay.width then
              "portrait"
            else
              "landscape";
          readOnly = true;
          description = "Orientation of the primary display: landscape or portrait.";
        };

        primaryIsPortrait = lib.mkOption {
          type = lib.types.bool;
          default = primaryDisplay != null && primaryDisplay.height > primaryDisplay.width;
          readOnly = true;
          description = "Whether the primary display is portrait-oriented.";
        };

        primaryIsUltrawide = lib.mkOption {
          type = lib.types.bool;
          default = primaryDisplay != null && primaryDisplay.width * 10 / primaryDisplay.height >= 21;
          readOnly = true;
          description = "Whether the primary display is ultra-wide.";
        };

        primaryScale = lib.mkOption {
          type = lib.types.float;
          default = if primaryDisplay != null then primaryDisplay.scale else 1.0;
          readOnly = true;
          description = "Scale factor of the primary display.";
        };

        primaryIsHighDpi = lib.mkOption {
          type = lib.types.bool;
          default = primaryDisplay != null && primaryDisplay.scale >= 2.0;
          readOnly = true;
          description = "Whether the primary display is high-DPI (scale >= 2.0).";
        };

        primaryIsHighRes = lib.mkOption {
          type = lib.types.bool;
          default = primaryDisplay != null && primaryDisplay.width * primaryDisplay.height >= 3686400;
          readOnly = true;
          description = "Whether the primary display has high resolution (pixel count >= ~QHD+).";
        };

        isMultiMonitor = lib.mkOption {
          type = lib.types.bool;
          default = builtins.length config.noughty.host.displays > 1;
          description = "Whether multiple displays are configured.";
          readOnly = true;
        };

        outputs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = map (d: d.output) config.noughty.host.displays;
          description = "List of all output connector names.";
          readOnly = true;
        };
      };

      # ── Keyboard layout configuration ─────────────────────────────

      keyboard = {
        layout = lib.mkOption {
          type = lib.types.str;
          default = "gb";
          description = ''
            XKB keyboard layout code (e.g. "gb", "us", "de").
            Used by services.xserver.xkb.layout, Hyprland kb_layout, and Wayfire xkb_layout.
            Defaults to "gb" (United Kingdom) so most hosts need not set this.
          '';
        };

        variant = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = ''
            XKB keyboard variant (e.g. "dvorak", "colemak").
            Empty string means the default variant for the layout.
          '';
        };

        consoleKeymap = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default =
            let
              # Map XKB layout codes to Linux console keymap names where they differ.
              # Most codes are identical; "gb" is the main exception (console uses "uk").
              xkbToConsole = {
                gb = "uk";
              };
            in
            xkbToConsole.${config.noughty.host.keyboard.layout} or config.noughty.host.keyboard.layout;
          description = ''
            Linux console keymap name, derived from keyboard.layout.
            Used by console.keyMap. For most layouts this equals keyboard.layout;
            "gb" maps to "uk" (the kbd database name for the British layout).
          '';
        };

        locale = lib.mkOption {
          type = lib.types.str;
          default =
            let
              xkbToLocale = {
                gb = "en_GB.UTF-8";
                us = "en_US.UTF-8";
                de = "de_DE.UTF-8";
                fr = "fr_FR.UTF-8";
                es = "es_ES.UTF-8";
                it = "it_IT.UTF-8";
                pt = "pt_PT.UTF-8";
                nl = "nl_NL.UTF-8";
                pl = "pl_PL.UTF-8";
                ru = "ru_RU.UTF-8";
                ja = "ja_JP.UTF-8";
                zh = "zh_CN.UTF-8";
                ko = "ko_KR.UTF-8";
              };
            in
            xkbToLocale.${config.noughty.host.keyboard.layout} or "en_US.UTF-8";
          description = ''
            POSIX locale string derived from keyboard.layout (e.g. "en_GB.UTF-8").
            Used by i18n.defaultLocale and LC_* settings on NixOS.
            Override explicitly if locale and keyboard layout differ
            (e.g. Swiss German: layout = "ch", locale = "de_CH.UTF-8").
          '';
        };
      };
    };

    # ── User identity ─────────────────────────────────────────────────

    user = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "nobody";
        description = "Primary username of the managed system.";
      };

      tags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Freeform tags for user role or persona classification.";
      };
    };

    # ── Network attributes ────────────────────────────────────────────

    network = {
      tailNet = lib.mkOption {
        type = lib.types.str;
        default = "drongo-gamma.ts.net";
        description = "Tailscale network domain.";
      };
    };
  };

  # ── Inject noughtyLib as a module argument ────────────────────────────

  config = {
    _module.args.noughtyLib = helpers {
      hostName = config.noughty.host.name;
      userName = config.noughty.user.name;
      hostTags = config.noughty.host.tags;
      userTags = config.noughty.user.tags;
    };
  };
}
