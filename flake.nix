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

    bzmenu.url = "https://github.com/e-tho/bzmenu/archive/refs/tags/v0.2.1.tar.gz";
    bzmenu.inputs.nixpkgs.follows = "nixpkgs";
    iwmenu.url = "https://github.com/e-tho/iwmenu/archive/refs/tags/v0.2.0.tar.gz";
    iwmenu.inputs.nixpkgs.follows = "nixpkgs";
    catppuccin.url = "github:catppuccin/nix";
    catppuccin.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "https://flakehub.com/f/nix-community/disko/1.12.0.tar.gz";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-needsreboot.url = "https://flakehub.com/f/wimpysworld/nixos-needsreboot/0.2.8.tar.gz";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
    nix-flatpak.url = "https://flakehub.com/f/gmodena/nix-flatpak/0.6.0.tar.gz";
    quickemu.url = "https://flakehub.com/f/quickemu-project/quickemu/*";
    quickemu.inputs.nixpkgs.follows = "nixpkgs";
    quickgui.url = "https://flakehub.com/f/quickemu-project/quickgui/*";
    quickgui.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    vscode-server.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    { self, nix-darwin, nixpkgs, ... }@inputs:
    let
      inherit (self) outputs;
      # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
      stateVersion = "24.11";
      helper = import ./lib { inherit inputs outputs stateVersion; };
    in
    {
      # home-manager build --flake $HOME/Zero/nix-config -L
      # home-manager switch -b backup --flake $HOME/Zero/nix-config
      # nix run nixpkgs#home-manager -- switch -b backup --flake "${HOME}/Zero/nix-config"
      homeConfigurations = {
        # .iso images
        "nixos@iso-console" = helper.mkHome {
          hostname = "iso-console";
          username = "nixos";
        };
        "nixos@iso-lomiri" = helper.mkHome {
          hostname = "iso-lomiri";
          username = "nixos";
          desktop = "lomiri";
        };
        "nixos@iso-pantheon" = helper.mkHome {
          hostname = "iso-pantheon";
          username = "nixos";
          desktop = "pantheon";
        };
        # Workstations
        "martin@phasma" = helper.mkHome {
          hostname = "phasma";
          desktop = "hyprland";
        };
        "martin@vader" = helper.mkHome {
          hostname = "vader";
          desktop = "hyprland";
        };
        "martin@shaa" = helper.mkHome {
          hostname = "shaa";
          desktop = "hyprland";
        };
        "martin@atrius" = helper.mkHome {
          hostname = "atrius";
          desktop = "hyprland";
        };
        "martin@tanis" = helper.mkHome {
          hostname = "tanis";
          desktop = "hyprland";
        };
        "martin@momin" = helper.mkHome {
          hostname = "momin";
          platform = "aarch64-darwin";
          desktop = "aqua";
        };
        "martin@krall" = helper.mkHome {
          hostname = "krall";
          platform = "x86_64-darwin";
          desktop = "aqua";
        };
        # palpatine/sidious are dual boot hosts, WSL2/Ubuntu and NixOS respectively.
        "martin@palpatine" = helper.mkHome { hostname = "palpatine"; };
        "martin@sidious" = helper.mkHome {
          hostname = "sidious";
          desktop = "pantheon";
        };
        # Servers
        "martin@malak" = helper.mkHome { hostname = "malak"; };
        "martin@revan" = helper.mkHome { hostname = "revan"; };
        # Steam Deck
        "deck@steamdeck" = helper.mkHome {
          hostname = "steamdeck";
          username = "deck";
        };
        # VMs
        "martin@blackace" = helper.mkHome { hostname = "blackace"; };
        "martin@defender" = helper.mkHome { hostname = "defender"; };
        "martin@fighter" = helper.mkHome { hostname = "fighter"; };
        "martin@crawler" = helper.mkHome { hostname = "crawler"; };
        "martin@dagger" = helper.mkHome {
          hostname = "dagger";
          desktop = "pantheon";
        };
      };
      nixosConfigurations = {
        # .iso images
        #  - nix build .#nixosConfigurations.{iso-console|iso-pantheon}.config.system.build.isoImage
        iso-console = helper.mkNixos {
          hostname = "iso-console";
          username = "nixos";
        };
        iso-lomiri = helper.mkNixos {
          hostname = "iso-lomiri";
          username = "nixos";
          desktop = "lomiri";
        };
        iso-pantheon = helper.mkNixos {
          hostname = "iso-pantheon";
          username = "nixos";
          desktop = "pantheon";
        };
        # Workstations
        #  - sudo nixos-rebuild boot --flake $HOME/Zero/nix-config
        #  - sudo nixos-rebuild switch --flake $HOME/Zero/nix-config
        #  - nix build .#nixosConfigurations.{hostname}.config.system.build.toplevel
        #  - nix run github:nix-community/nixos-anywhere -- --flake '.#{hostname}' root@{ip-address}
        phasma = helper.mkNixos {
          hostname = "phasma";
          desktop = "hyprland";
        };
        vader = helper.mkNixos {
          hostname = "vader";
          desktop = "hyprland";
        };
        shaa = helper.mkNixos {
          hostname = "shaa";
          desktop = "hyprland";
        };
        atrius = helper.mkNixos {
          hostname = "atrius";
          desktop = "hyprland";
        };
        tanis = helper.mkNixos {
          hostname = "tanis";
          desktop = "hyprland";
        };
        sidious = helper.mkNixos {
          hostname = "sidious";
          desktop = "pantheon";
        };
        # Servers
        malak = helper.mkNixos { hostname = "malak"; };
        revan = helper.mkNixos { hostname = "revan"; };
        # VMs
        crawler = helper.mkNixos { hostname = "crawler"; };
        dagger = helper.mkNixos {
          hostname = "dagger";
          desktop = "pantheon";
        };
      };
      #nix run nix-darwin -- switch --flake ~/Zero/nix-config
      #nix build .#darwinConfigurations.{hostname}.config.system.build.toplevel
      darwinConfigurations = {
        momin = helper.mkDarwin {
          hostname = "momin";
        };
        krall = helper.mkDarwin {
          hostname = "krall";
          platform = "x86_64-darwin";
        };
      };
      # Custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs; };
      # Custom NixOS modules
      nixosModules = import ./modules/nixos;
      # Custom packages; acessible via 'nix build', 'nix shell', etc
      packages = helper.forAllSystems (system:
        let
          # Import nixpkgs for the target system, applying overlays directly
          pkgsWithOverlays = import nixpkgs {
             inherit system;
             config = { allowUnfree = true; }; # Ensure consistent config
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
      
      # Expose input packages directly
      inherit (inputs) bzmenu iwmenu;
    };
}
