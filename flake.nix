{
  description = "Wimpy's NixOS and Home Manager Configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    # You can access packages and modules from different nixpkgs revs at the same time.
    # See 'unstable-packages' overlay in 'overlays/default.nix'.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    catppuccin.url = "github:catppuccin/nix";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-24.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nixos-needtoreboot.url = "github:thefossguy/nixos-needsreboot";
    nixos-needtoreboot.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # FlakeHub
    catppuccin-vsc.url = "https://flakehub.com/f/catppuccin/vscode/*.tar.gz";
    catppuccin-vsc.inputs.nixpkgs.follows = "nixpkgs";

    antsy-alien-attack-pico.url = "https://flakehub.com/f/wimpysworld/antsy-alien-attack-pico/*.tar.gz";
    antsy-alien-attack-pico.inputs.nixpkgs.follows = "nixpkgs";

    nix-flatpak.url = "https://flakehub.com/f/gmodena/nix-flatpak/*.tar.gz";

    nix-snapd.url = "https://flakehub.com/f/io12/nix-snapd/*.tar.gz";
    nix-snapd.inputs.nixpkgs.follows = "nixpkgs";

    quickemu.url = "https://flakehub.com/f/quickemu-project/quickemu/*.tar.gz";
    quickemu.inputs.nixpkgs.follows = "nixpkgs";
    quickgui.url = "https://flakehub.com/f/quickemu-project/quickgui/*.tar.gz";
    quickgui.inputs.nixpkgs.follows = "nixpkgs";

    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*.tar.gz";
    fh.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    { self
    , nixpkgs
    , ...
    }@inputs:
    let
      inherit (self) outputs;
      # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
      stateVersion = "24.05";
      libx = import ./lib { inherit inputs outputs stateVersion; };
    in
    {
      # home-manager switch -b backup --flake $HOME/Zero/nix-config
      # nix run nixpkgs#home-manager -- switch -b backup --flake "${HOME}/Zero/nix-config"
      homeConfigurations = {
        # .iso images
        "nixos@iso-console" =  libx.mkHome { hostname = "iso-console";  username = "nixos"; };
        "nixos@iso-gnome" =    libx.mkHome { hostname = "iso-gnome";    username = "nixos"; desktop = "gnome"; };
        "nixos@iso-mate" =     libx.mkHome { hostname = "iso-mate";     username = "nixos"; desktop = "mate"; };
        "nixos@iso-pantheon" = libx.mkHome { hostname = "iso-pantheon"; username = "nixos"; desktop = "pantheon"; };
        # Workstations
        "martin@phasma" = libx.mkHome { hostname = "phasma"; desktop = "pantheon"; };
        "martin@vader"  = libx.mkHome { hostname = "vader";  desktop = "pantheon"; };
        "martin@tanis"  = libx.mkHome { hostname = "tanis";  desktop = "gnome"; };
        # dooku/tyranus are dual boot hosts, macOS and NixOS respectively.
        "martin@dooku"     = libx.mkHome { hostname = "dooku";   platform = "aarch64-darwin"; desktop = "aqua";};
        "martin@tyranus"   = libx.mkHome { hostname = "tyranus"; platform = "aarch64-linux";  desktop = "gnome"; };
        # palpatine/sidious are dual boot hosts, WSL2/Ubuntu and NixOS respectively.
        "martin@palpatine" = libx.mkHome { hostname = "palpatine"; };
        "martin@sidious"   = libx.mkHome { hostname = "sidious"; desktop = "gnome"; };
        # Servers
        "martin@revan" = libx.mkHome { hostname = "revan"; };
        "martin@brix"  = libx.mkHome { hostname = "brix"; };
        "martin@skull" = libx.mkHome { hostname = "skull"; };
        # Steam Deck
        "deck@steamdeck" = libx.mkHome { hostname = "steamdeck"; username = "deck"; };
        # VMs
        "martin@minimech"     = libx.mkHome { hostname = "minimech"; };
        "martin@scrubber"     = libx.mkHome { hostname = "scrubber"; desktop = "pantheon"; };
        "martin@lima-builder" = libx.mkHome { hostname = "lima-builder"; };
        "martin@lima-default" = libx.mkHome { hostname = "lima-default"; };
      };
      nixosConfigurations = {
        # .iso images
        #  - nix build .#nixosConfigurations.{iso-console|iso-desktop}.config.system.build.isoImage
        iso-console  = libx.mkHost { hostname = "iso-console";  username = "nixos"; };
        iso-gnome    = libx.mkHost { hostname = "iso-gnome";    username = "nixos"; desktop = "gnome"; };
        iso-mate     = libx.mkHost { hostname = "iso-mate";     username = "nixos"; desktop = "mate"; };
        iso-pantheon = libx.mkHost { hostname = "iso-pantheon"; username = "nixos"; desktop = "pantheon"; };
        # Workstations
        #  - sudo nixos-rebuild boot --flake $HOME/Zero/nix-config
        #  - sudo nixos-rebuild switch --flake $HOME/Zero/nix-config
        #  - nix build .#nixosConfigurations.{hostname}.config.system.build.toplevel
        phasma  = libx.mkHost { hostname = "phasma";  desktop = "pantheon"; };
        vader   = libx.mkHost { hostname = "vader";   desktop = "pantheon"; };
        tanis   = libx.mkHost { hostname = "tanis";   desktop = "gnome"; };
        tyranus = libx.mkHost { hostname = "tyranus"; desktop = "gnome"; platform = "aarch64-linux"; };
        sidious = libx.mkHost { hostname = "sidious"; desktop = "gnome"; };
        # Servers
        revan = libx.mkHost { hostname = "revan"; };
        brix  = libx.mkHost { hostname = "brix"; };
        skull = libx.mkHost { hostname = "skull"; };
        # VMs
        minimech = libx.mkHost { hostname = "minimech"; };
        scrubber = libx.mkHost { hostname = "scrubber"; desktop = "pantheon"; };
      };

      # Devshell for bootstrapping; acessible via 'nix develop' or 'nix-shell' (legacy)
      devShells = libx.forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in import ./shell.nix { inherit pkgs; }
      );

      # Custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs; };

      # Custom packages; acessible via 'nix build', 'nix shell', etc
      packages = libx.forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in import ./pkgs { inherit pkgs; }
      );
    };
}
