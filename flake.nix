{
  description = "Wimpy's NixOS and Home Manager Configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    # You can access packages and modules from different nixpkgs revs at the same time.
    # See 'unstable-packages' overlay in 'overlays/default.nix'.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-23.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-formatter-pack.url = "github:Gerschtli/nix-formatter-pack";
    nix-formatter-pack.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # FlakeHub
    antsy-alien-attack-pico.url = "https://flakehub.com/f/wimpysworld/antsy-alien-attack-pico/*.tar.gz";
    antsy-alien-attack-pico.inputs.nixpkgs.follows = "nixpkgs";

    crafts-flake.url = "https://flakehub.com/f/jnsgruk/crafts-flake/=0.4.3.tar.gz";
    crafts-flake.inputs.nixpkgs.follows = "nixpkgs";
    nix-snapd.url = "https://flakehub.com/f/io12/nix-snapd/0.1.*.tar.gz";
    nix-snapd.inputs.nixpkgs.follows = "nixpkgs";

    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*.tar.gz";
    fh.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    { self
    , nix-formatter-pack
    , nixpkgs
    , ...
    }@inputs:
    let
      inherit (self) outputs;
      # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
      stateVersion = "23.11";
      libx = import ./lib { inherit inputs outputs stateVersion; };
    in
    {
      # home-manager switch -b backup --flake $HOME/Zero/nix-config
      # nix run nixpkgs#home-manager -- switch -b backup --flake "${HOME}/Zero/nix-config"
      homeConfigurations = {
        # .iso images
        "nixos@iso-console" = libx.mkHome { hostname = "iso-console"; username = "nixos"; };
        "nixos@iso-desktop" = libx.mkHome { hostname = "iso-desktop"; username = "nixos"; desktop = "pantheon"; };
        # Workstations
        "martin@phasma" = libx.mkHome { hostname = "phasma"; username = "martin"; desktop = "pantheon"; };
        "martin@vader" = libx.mkHome { hostname = "vader"; username = "martin"; desktop = "pantheon"; };
        "martin@tanis" = libx.mkHome { hostname = "tanis"; username = "martin"; desktop = "gnome"; };
        # dooku/tyranus are dual boot hosts, macOS and NixOS respectively.
        "martin@dooku" = libx.mkHome { hostname = "dooku"; username = "martin"; platform = "aarch64-darwin"; desktop = "aqua";};
        "martin@tyranus" = libx.mkHome { hostname = "tyranus"; username = "martin"; platform = "aarch64-linux"; desktop = "pantheon"; };
        # palpatine/sidious are dual boot hosts, WSL2/Ubuntu and NixOS respectively.
        "martin@palpatine" = libx.mkHome { hostname = "palpatine"; username = "martin"; };
        "martin@sidious" = libx.mkHome { hostname = "sidious"; username = "martin"; desktop = "gnome"; };

        # Servers
        "martin@brix" = libx.mkHome { hostname = "brix"; username = "martin"; };
        "martin@skull" = libx.mkHome { hostname = "skull"; username = "martin"; };
        # Steam Deck
        "deck@steamdeck" = libx.mkHome { hostname = "steamdeck"; username = "deck"; };
        # VMs
        "martin@minimech" = libx.mkHome { hostname = "minimech"; username = "martin"; };
        "martin@scrubber" = libx.mkHome { hostname = "scrubber"; username = "martin"; desktop = "pantheon"; };
        "martin@lima-builder" = libx.mkHome { hostname = "lima-builder"; username = "martin"; };
        "martin@lima-default" = libx.mkHome { hostname = "lima-default"; username = "martin"; };
      };
      nixosConfigurations = {
        # .iso images
        #  - nix build .#nixosConfigurations.{iso-console|iso-desktop}.config.system.build.isoImage
        iso-console = libx.mkHost { hostname = "iso-console"; username = "nixos"; installer = nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"; };
        iso-desktop = libx.mkHost { hostname = "iso-desktop"; username = "nixos"; installer = nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares.nix"; desktop = "pantheon"; };
        # Workstations
        #  - sudo nixos-rebuild boot --flake $HOME/Zero/nix-config
        #  - sudo nixos-rebuild switch --flake $HOME/Zero/nix-config
        #  - nix build .#nixosConfigurations.{hostname}.config.system.build.toplevel
        phasma = libx.mkHost { hostname = "phasma"; username = "martin"; desktop = "pantheon"; };
        vader = libx.mkHost { hostname = "vader"; username = "martin"; desktop = "pantheon"; };
        tanis = libx.mkHost { hostname = "tanis"; username = "martin"; desktop = "gnome"; };
        tyranus = libx.mkHost { hostname = "tyranus"; username = "martin"; desktop = "pantheon"; platform = "aarch64-linux"; };
        sidious = libx.mkHost { hostname = "sidious"; username = "martin"; desktop = "gnome"; };
        # Servers
        brix = libx.mkHost { hostname = "brix"; username = "martin"; };
        skull = libx.mkHost { hostname = "skull"; username = "martin"; };
        # VMs
        minimech = libx.mkHost { hostname = "minimech"; username = "martin"; };
        scrubber = libx.mkHost { hostname = "scrubber"; username = "martin"; desktop = "pantheon"; };
      };

      # Devshell for bootstrapping; acessible via 'nix develop' or 'nix-shell' (legacy)
      devShells = libx.forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in import ./shell.nix { inherit pkgs; }
      );

      # nix fmt
      formatter = libx.forAllSystems (system:
        nix-formatter-pack.lib.mkFormatter {
          pkgs = nixpkgs.legacyPackages.${system};
          config.tools = {
            alejandra.enable = false;
            deadnix.enable = true;
            nixpkgs-fmt.enable = true;
            statix.enable = true;
          };
        }
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
