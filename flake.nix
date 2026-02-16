{
  description = "Wimpy's NixOS, nix-darwin and Home Manager Configuration";
  inputs = {
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
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
    disko.url = "https://flakehub.com/f/nix-community/disko/1.12.0.tar.gz";
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
      helper = import ./lib { inherit inputs outputs stateVersion; };

      # System registry - central definition of all systems and their properties
      systems = {
        # ISO Image
        iso-console = {
          type = "iso";
          username = "nixos";
        };
        # Workstations
        bane = {
          type = "workstation";
          desktop = "hyprland";
        };
        phasma = {
          type = "workstation";
          desktop = "hyprland";
        };
        vader = {
          type = "workstation";
          desktop = "hyprland";
        };
        shaa = {
          type = "workstation";
          desktop = "hyprland";
        };
        atrius = {
          type = "workstation";
          desktop = "hyprland";
        };
        tanis = {
          type = "workstation";
          desktop = "hyprland";
        };
        sidious = {
          type = "workstation";
          desktop = "hyprland";
        };

        # Darwin systems
        momin = {
          type = "darwin";
        };
        # Dual boot (WSL/Ubuntu variant)
        palpatine = {
          type = "wsl";
        };

        # Servers
        malak = {
          type = "server";
        };
        maul = {
          type = "server";
        };
        revan = {
          type = "server";
        };

        # Steam Deck
        steamdeck = {
          type = "gaming";
          username = "deck";
        };

        # VMs (NixOS)
        crawler = {
          type = "vm";
        };
        dagger = {
          type = "vm";
          desktop = "hyprland";
        };

        # VMs (Lima/Home Manager only)
        blackace = {
          type = "lima";
        };
        defender = {
          type = "lima";
        };
        fighter = {
          type = "lima";
        };
      };

      # Type defaults for different system types
      typeDefaults = {
        iso = {
          username = "nixos";
          platform = "x86_64-linux";
          desktop = null;
        };
        workstation = {
          username = "martin";
          platform = "x86_64-linux";
          desktop = "hyprland";
        };
        server = {
          username = "martin";
          platform = "x86_64-linux";
          desktop = null;
        };
        vm = {
          username = "martin";
          platform = "x86_64-linux";
          desktop = null;
        };
        lima = {
          username = "martin";
          platform = "x86_64-linux";
          desktop = null;
        };
        darwin = {
          username = "martin";
          platform = "aarch64-darwin";
          desktop = "aqua";
        };
        wsl = {
          username = "martin";
          platform = "x86_64-linux";
          desktop = null;
        };
        gaming = {
          username = "deck";
          platform = "x86_64-linux";
          desktop = "gamescope";
        };
      };

    in
    {
      # Expose lib so it can be used by the helper functions
      lib = helper;

      # Generated system configurations
      nixosConfigurations =
        let
          allNixos =
            helper.generateConfigs "workstation" systems typeDefaults
            // helper.generateConfigs "server" systems typeDefaults
            // helper.generateConfigs "vm" systems typeDefaults
            // helper.generateConfigs "iso" systems typeDefaults;
        in
        nixpkgs.lib.mapAttrs (name: config: helper.mkNixos config) allNixos;

      darwinConfigurations = nixpkgs.lib.mapAttrs (name: config: helper.mkDarwin config) (
        helper.generateConfigs "darwin" systems typeDefaults
      );

      homeConfigurations =
        let
          allHomes =
            helper.generateConfigs "workstation" systems typeDefaults
            // helper.generateConfigs "server" systems typeDefaults
            // helper.generateConfigs "vm" systems typeDefaults
            // helper.generateConfigs "lima" systems typeDefaults
            // helper.generateConfigs "darwin" systems typeDefaults
            // helper.generateConfigs "wsl" systems typeDefaults
            // helper.generateConfigs "gaming" systems typeDefaults;
        in
        nixpkgs.lib.mapAttrs' (
          name: config: nixpkgs.lib.nameValuePair "${config.username}@${name}" (helper.mkHome config)
        ) allHomes;
      # Custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs; };
      # Custom NixOS modules
      nixosModules = import ./modules/nixos;
      # Custom packages; accessible via 'nix build', 'nix shell', etc
      packages = helper.forAllSystems (
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
      formatter = helper.forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      # Creates a devshell for working with this flake via direnv.
      devShells = helper.forAllSystems (
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
