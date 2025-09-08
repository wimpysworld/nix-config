{
  description = "Wimpy's NixOS, nix-darwin and Home Manager Configuration";
  inputs = {
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-25.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-ai-tools.url = "github:numtide/nix-ai-tools";
    nix-ai-tools.inputs.nixpkgs.follows = "nixpkgs-unstable";
    bzmenu.url = "https://github.com/e-tho/bzmenu/archive/refs/tags/v0.2.1.tar.gz";
    bzmenu.inputs.nixpkgs.follows = "nixpkgs";
    iwmenu.url = "https://github.com/e-tho/iwmenu/archive/refs/tags/v0.2.0.tar.gz";
    iwmenu.inputs.nixpkgs.follows = "nixpkgs";
    catppuccin.url = "github:catppuccin/nix";
    catppuccin.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "https://flakehub.com/f/nix-community/disko/1.12.0.tar.gz";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    kolide-launcher.url = "github:/kolide/nix-agent/main";
    kolide-launcher.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-needsreboot.url = "https://flakehub.com/f/wimpysworld/nixos-needsreboot/0.2.9.tar.gz";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
    nix-flatpak.url = "https://flakehub.com/f/gmodena/nix-flatpak/0.6.0.tar.gz";
    mac-app-util.url = "github:hraban/mac-app-util";
    mac-app-util.inputs.nixpkgs.follows = "nixpkgs";
    quickemu.url = "https://flakehub.com/f/quickemu-project/quickemu/*";
    quickemu.inputs.nixpkgs.follows = "nixpkgs";
    quickgui.url = "https://flakehub.com/f/quickemu-project/quickgui/*";
    quickgui.inputs.nixpkgs.follows = "nixpkgs";
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
      stateVersion = "24.11";
      helper = import ./lib { inherit inputs outputs stateVersion; };

      # System registry - central definition of all systems and their properties
      systems = {
        # ISO Images
        iso-console = {
          type = "iso";
          username = "nixos";
        };
        iso-lomiri = {
          type = "iso";
          username = "nixos";
          desktop = "lomiri";
        };
        iso-pantheon = {
          type = "iso";
          username = "nixos";
          desktop = "pantheon";
        };

        # Workstations
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
          desktop = "pantheon";
        };

        # Darwin systems
        bane = {
          type = "darwin";
          username = "martin.wimpress";
          platform = "aarch64-darwin";
          desktop = "aqua";
        };
        krall = {
          type = "darwin";
          platform = "x86_64-darwin";
          desktop = "aqua";
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
          desktop = "pantheon";
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
          workstations = helper.generateConfigs "workstation" systems typeDefaults;
          servers = helper.generateConfigs "server" systems typeDefaults;
          vms = helper.generateConfigs "vm" systems typeDefaults;
          isos = helper.generateConfigs "iso" systems typeDefaults;
          allNixos = workstations // servers // vms // isos;
        in
        nixpkgs.lib.mapAttrs (name: config: helper.mkNixos config) allNixos;

      darwinConfigurations =
        let
          darwinSystems = helper.generateConfigs "darwin" systems typeDefaults;
        in
        nixpkgs.lib.mapAttrs (name: config: helper.mkDarwin config) darwinSystems;

      homeConfigurations =
        let
          workstations = helper.generateConfigs "workstation" systems typeDefaults;
          servers = helper.generateConfigs "server" systems typeDefaults;
          vms = helper.generateConfigs "vm" systems typeDefaults;
          lima = helper.generateConfigs "lima" systems typeDefaults;
          darwin = helper.generateConfigs "darwin" systems typeDefaults;
          wsl = helper.generateConfigs "wsl" systems typeDefaults;
          gaming = helper.generateConfigs "gaming" systems typeDefaults;
          allHomes = workstations // servers // vms // lima // darwin // wsl // gaming;
        in
        nixpkgs.lib.mapAttrs' (
          name: config: nixpkgs.lib.nameValuePair "${config.username}@${name}" (helper.mkHome config)
        ) allHomes;
      # Custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs; };
      # Custom NixOS modules
      nixosModules = import ./modules/nixos;
      # Custom packages; acessible via 'nix build', 'nix shell', etc
      packages = helper.forAllSystems (
        system:
        let
          # Import nixpkgs for the target system, applying overlays directly
          pkgsWithOverlays = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
            }; # Ensure consistent config
            # Pass the list of overlay functions directly
            overlays = builtins.attrValues self.overlays;
          };
          # Import the function from pkgs/default.nix
          pkgsFunction = import ./pkgs;
          # Call the function with the fully overlaid package set
          customPkgs = pkgsFunction pkgsWithOverlays;
        in
        # Return the set of custom packages
        customPkgs
      );
      # Formatter for .nix files, available via 'nix fmt'
      formatter = helper.forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

      # Creates a devshell for working with this flake via direnv.
      devShells = helper.forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        {
          default = pkgs.mkShell {
            packages =
              with pkgs;
              [
                bc
                git
                home-manager
                inputs.determinate.packages.${system}.default
                inputs.disko.packages.${system}.default
                inputs.fh.packages.${system}.default
                jq
                just
                micro
                nh
                nixfmt-tree
                nixpkgs-fmt
                nixd
                nix-output-monitor
                nvd
                sops
                tree
              ]
              ++ lib.optionals pkgs.stdenv.isLinux [
                inputs.nixos-needsreboot.packages.${system}.default
              ];
          };
        }
      );
    };
}
