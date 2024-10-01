{
  description = "Wimpy's NixOS, nix-darwin and Home Manager Configuration";
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/nixos/nixpkgs/0.2405.*";
    nixpkgs-unstable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0";

    auto-cpufreq.url = "github:AdnanHodzic/auto-cpufreq";
    auto-cpufreq.inputs.nixpkgs.follows = "nixpkgs-unstable";

    catppuccin.url = "github:catppuccin/nix";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-24.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nixos-needtoreboot.url = "github:thefossguy/nixos-needsreboot";
    nixos-needtoreboot.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # FlakeHub
    catppuccin-vsc.url = "https://flakehub.com/f/catppuccin/vscode/*.tar.gz";
    catppuccin-vsc.inputs.nixpkgs.follows = "nixpkgs";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0";

    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/0";

    antsy-alien-attack-pico.url = "https://flakehub.com/f/wimpysworld/antsy-alien-attack-pico/*.tar.gz";
    antsy-alien-attack-pico.inputs.nixpkgs.follows = "nixpkgs";

    nix-flatpak.url = "https://flakehub.com/f/gmodena/nix-flatpak/*.tar.gz";

    nix-snapd.url = "https://flakehub.com/f/io12/nix-snapd/*.tar.gz";
    nix-snapd.inputs.nixpkgs.follows = "nixpkgs";

    quickemu.url = "https://flakehub.com/f/quickemu-project/quickemu/*.tar.gz";
    quickemu.inputs.nixpkgs.follows = "nixpkgs";
    quickgui.url = "https://flakehub.com/f/quickemu-project/quickgui/*.tar.gz";
    quickgui.inputs.nixpkgs.follows = "nixpkgs";
    stream-sprout.url = "https://flakehub.com/f/wimpysworld/stream-sprout/*.tar.gz";
    stream-sprout.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    { self, nix-darwin, nixpkgs, ... }@inputs:
    let
      inherit (self) outputs;
      # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
      stateVersion = "24.05";
      helper = import ./lib { inherit inputs outputs stateVersion; };
    in
    {
      # home-manager switch -b backup --flake $HOME/Zero/nix-config
      # nix run nixpkgs#home-manager -- switch -b backup --flake "${HOME}/Zero/nix-config"
      homeConfigurations = {
        # .iso images
        "nixos@iso-console" = helper.mkHome {
          hostname = "iso-console";
          username = "nixos";
        };
        "nixos@iso-gnome" = helper.mkHome {
          hostname = "iso-gnome";
          username = "nixos";
          desktop = "gnome";
        };
        "nixos@iso-mate" = helper.mkHome {
          hostname = "iso-mate";
          username = "nixos";
          desktop = "mate";
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
          desktop = "gnome";
        };
        # Servers
        "martin@revan" = helper.mkHome { hostname = "revan"; };
        # Steam Deck
        "deck@steamdeck" = helper.mkHome {
          hostname = "steamdeck";
          username = "deck";
        };
        # VMs
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
        #  - nix build .#nixosConfigurations.{iso-console|iso-desktop}.config.system.build.isoImage
        iso-console = helper.mkNixos {
          hostname = "iso-console";
          username = "nixos";
        };
        iso-gnome = helper.mkNixos {
          hostname = "iso-gnome";
          username = "nixos";
          desktop = "gnome";
        };
        iso-mate = helper.mkNixos {
          hostname = "iso-mate";
          username = "nixos";
          desktop = "mate";
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
          desktop = "gnome";
        };
        # Servers
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
      # Custom packages; acessible via 'nix build', 'nix shell', etc
      packages = helper.forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
      # Formatter for .nix files, available via 'nix fmt'
      formatter = helper.forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
