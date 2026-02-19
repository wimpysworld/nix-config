{
  description = "Wimpy's NixOS, nix-darwin and Home Manager Configuration";
  inputs = {
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2511.*";
    nixpkgs-unstable.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*";
    nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-25.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-ai-tools.url = "github:numtide/nix-ai-tools";
    nix-ai-tools.inputs.nixpkgs.follows = "nixpkgs-unstable";
    opencode.url = "github:anomalyco/opencode";
    opencode.inputs.nixpkgs.follows = "nixpkgs-unstable";
    bzmenu.url = "https://github.com/e-tho/bzmenu/archive/refs/tags/v0.3.0.tar.gz";
    bzmenu.inputs.nixpkgs.follows = "nixpkgs";
    iwmenu.url = "https://github.com/e-tho/iwmenu/archive/refs/tags/v0.3.0.tar.gz";
    iwmenu.inputs.nixpkgs.follows = "nixpkgs";
    pwmenu.url = "https://github.com/e-tho/pwmenu/archive/refs/tags/v0.3.0.tar.gz";
    pwmenu.inputs.nixpkgs.follows = "nixpkgs";
    catppuccin.url = "https://github.com/catppuccin/nix/archive/refs/tags/v25.11.tar.gz";
    catppuccin.inputs.nixpkgs.follows = "nixpkgs";
    direnv-instant.url = "github:Mic92/direnv-instant";
    direnv-instant.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "https://flakehub.com/f/nix-community/disko/1.13.0.tar.gz";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    kolide-launcher.url = "github:/kolide/nix-agent/main";
    kolide-launcher.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
    nix-flatpak.url = "https://flakehub.com/f/gmodena/nix-flatpak/0.6.0.tar.gz";
    mac-app-util.url = "github:hraban/mac-app-util";
    mac-app-util.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    vscode-server.inputs.nixpkgs.follows = "nixpkgs";
    xdg-override.url = "github:koiuo/xdg-override";
    xdg-override.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    {
      self,
      nix-darwin,
      nixpkgs,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
      stateVersion = "25.11";
      darwinStateVersion = 6;

      # User profiles - per-user metadata keyed by username.
      # Looked up by resolveEntry based on the resolved username for each system.
      users = {
        martin = {
          tags = [ "developer" ];
        };
      };

      builder = import ./lib {
        inherit
          inputs
          outputs
          stateVersion
          darwinStateVersion
          users
          ;
      };

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
      systems = {

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
        };
        bane = {
          kind = "computer";
          platform = "x86_64-linux";
          formFactor = "laptop";
          gpu.vendors = [ "amd" ];
          tags = [ "policy" ];
        };
        tanis = {
          kind = "computer";
          platform = "x86_64-linux";
          formFactor = "laptop";
          gpu.vendors = [ "amd" ];
          tags = [ "thinkpad" ];
        };
        shaa = {
          kind = "computer";
          platform = "x86_64-linux";
          formFactor = "laptop";
          gpu.vendors = [ "amd" ];
          tags = [ "thinkpad" ];
        };
        atrius = {
          kind = "computer";
          platform = "x86_64-linux";
          formFactor = "laptop";
          gpu.vendors = [ "amd" ];
          tags = [ "thinkpad" ];
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
        };
        felkor = {
          kind = "computer";
          platform = "x86_64-linux";
          formFactor = "laptop";
          gpu.vendors = [ "amd" ];
          tags = [ "thinkpad" ];
        };

        # Gaming - non-standard username and desktop, so both explicit
        steamdeck = {
          kind = "computer";
          platform = "x86_64-linux";
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
      };

    in
    {
      # Expose lib so it can be used by the builder functions
      lib = builder;

      # Generated system configurations
      nixosConfigurations =
        let
          allNixos = builder.generateConfigs (
            e: builder.isLinuxEntry e && !builder.isISOEntry e && !builder.isHomeOnlyEntry e
          ) systems;
          allISO = builder.generateConfigs builder.isISOEntry systems;
        in
        nixpkgs.lib.mapAttrs (_name: config: builder.mkNixos config) (allNixos // allISO);

      darwinConfigurations = nixpkgs.lib.mapAttrs (_name: config: builder.mkDarwin config) (
        builder.generateConfigs builder.isDarwinEntry systems
      );

      homeConfigurations =
        let
          allHomes = builder.generateConfigs (_e: true) systems;
        in
        nixpkgs.lib.mapAttrs' (
          _name: config:
          nixpkgs.lib.nameValuePair "${config.username}@${config.hostname}" (builder.mkHome config)
        ) allHomes;
      # Custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs; };
      # Custom NixOS modules
      nixosModules = import ./modules/nixos;
      # Custom packages; accessible via 'nix build', 'nix shell', etc
      packages = builder.forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = builtins.attrValues self.overlays;
          };
          # Re-export packages from flake inputs that might not support all platforms
          optionalFlakePackage =
            name: flakeInput:
            nixpkgs.lib.optionalAttrs (flakeInput.packages ? ${system}) {
              ${name} = flakeInput.packages.${system}.default;
            };
          # Like optionalFlakePackage but restricted to Linux systems;
          # some flake inputs provide Darwin outputs that fail to compile
          # because they depend on Linux-specific services.
          linuxOnlyFlakePackage =
            name: flakeInput:
            nixpkgs.lib.optionalAttrs (
              nixpkgs.lib.hasSuffix "linux" system && flakeInput.packages ? ${system}
            ) { ${name} = flakeInput.packages.${system}.default; };
          # Filter local packages by meta.platforms so that packages which
          # cannot build on the current system are excluded from the output.
          # This prevents flakehub-push deep evaluation from hitting
          # "not available on the requested hostPlatform" assertions.
          filterLocalPackages =
            localPkgs:
            nixpkgs.lib.filterAttrs (
              _name: pkg:
              let
                platforms = pkg.meta.platforms or [ ];
              in
              platforms == [ ] || builtins.elem system platforms
            ) localPkgs;
        in
        filterLocalPackages (import ./pkgs pkgs)
        // linuxOnlyFlakePackage "bzmenu" inputs.bzmenu
        // linuxOnlyFlakePackage "iwmenu" inputs.iwmenu
        // linuxOnlyFlakePackage "pwmenu" inputs.pwmenu
      );
      # Formatter for .nix files, available via 'nix fmt'
      formatter = builder.forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      # Creates a devshell for working with this flake via direnv.
      devShells = builder.forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = builtins.attrValues self.overlays;
          };
          # Some flake inputs don't support all platforms (e.g., determinate doesn't support x86_64-darwin)
          optionalFlakePackage =
            flakeInput:
            inputs.nixpkgs.lib.optional (flakeInput.packages ? ${system}) flakeInput.packages.${system}.default;
        in
        {
          default = pkgs.mkShell {
            packages =
              with pkgs;
              [
                bc
                deadnix
                git
                home-manager
                hyperfine
                jq
                just
                micro
                nh
                nixd
                nixfmt-tree
                nixfmt
                nix-output-monitor
                openssh
                sops
                statix
                tree
              ]
              ++ optionalFlakePackage inputs.determinate
              ++ optionalFlakePackage inputs.disko
              ++ optionalFlakePackage inputs.fh;
          };
        }
      );
    };
}
