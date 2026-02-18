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
      displays = config.noughty.host.displays;
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
        description = "Freeform tags for host classification (e.g. \"streamstation\", \"thinkpad\").";
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
          default = lib.mkDefault (config.noughty.host.desktop != null);
          description = "Whether this host is a workstation (has a desktop environment).";
        };

        server = lib.mkOption {
          type = lib.types.bool;
          default = lib.mkDefault (config.noughty.host.kind == "server");
          description = "Whether this host is a server.";
        };

        laptop = lib.mkOption {
          type = lib.types.bool;
          default = lib.mkDefault (config.noughty.host.formFactor == "laptop");
          description = "Whether this host is a laptop.";
        };

        iso = lib.mkOption {
          type = lib.types.bool;
          default = lib.mkDefault false;
          description = "Whether this host is an ISO image build.";
        };

        vm = lib.mkOption {
          type = lib.types.bool;
          default = lib.mkDefault (config.noughty.host.kind == "vm");
          description = "Whether this host is a virtual machine.";
        };

        darwin = lib.mkOption {
          type = lib.types.bool;
          default = lib.mkDefault (config.noughty.host.os == "darwin");
          description = "Whether this host runs macOS (Darwin).";
        };

        linux = lib.mkOption {
          type = lib.types.bool;
          default = lib.mkDefault (config.noughty.host.os == "linux");
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
            ]
          );
          default = [ ];
          description = "GPU vendors present in this host.";
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

        hasAny = lib.mkOption {
          type = lib.types.bool;
          default = config.noughty.host.gpu.vendors != [ ];
          description = "Whether this host has any GPU. Derived from gpu.vendors.";
          readOnly = true;
        };

        hasCuda = lib.mkOption {
          type = lib.types.bool;
          default = lib.elem "nvidia" config.noughty.host.gpu.vendors;
          description = "Whether this host supports CUDA. Derived from gpu.vendors.";
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
