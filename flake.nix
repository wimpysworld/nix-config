{
  description = "Wimpy's NixOS, nix-darwin and Home Manager Configuration";
  inputs = {
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*";
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    #nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs.url = "https://flakehub.com/f/nixos/nixpkgs/0.2411.*";
    nixpkgs-unstable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/*";
    nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-24.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    vscode-server.inputs.nixpkgs.follows = "nixpkgs";

    catppuccin.url = "https://flakehub.com/f/catppuccin/nix/*";
    catppuccin-vsc.url = "https://flakehub.com/f/catppuccin/vscode/*";
    catppuccin-vsc.inputs.nixpkgs.follows = "nixpkgs-unstable";
    disko.url = "https://flakehub.com/f/nix-community/disko/1.11.0.tar.gz";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "https://flakehub.com/f/NixOS/nixos-hardware/*";
    nixos-needsreboot.url = "https://flakehub.com/f/wimpysworld/nixos-needsreboot/0.2.6.tar.gz";
    nixos-needsreboot.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
    nix-flatpak.url = "https://flakehub.com/f/gmodena/nix-flatpak/*";
    nix-snapd.url = "https://flakehub.com/f/io12/nix-snapd/*";
    nix-snapd.inputs.nixpkgs.follows = "nixpkgs";
    quickemu.url = "https://flakehub.com/f/quickemu-project/quickemu/*";
    quickemu.inputs.nixpkgs.follows = "nixpkgs";
    quickgui.url = "https://flakehub.com/f/quickemu-project/quickgui/*";
    quickgui.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "https://flakehub.com/f/Mic92/sops-nix/0.1.887.tar.gz";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
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
      packages = helper.forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
      # Formatter for .nix files, available via 'nix fmt'
      formatter = helper.forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
