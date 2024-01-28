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

    crafts-flake.url = "https://flakehub.com/f/jnsgruk/crafts-flake/0.3.*.tar.gz";
    crafts-flake.inputs.nixpkgs.follows = "nixpkgs";
    nix-snapd.url = "https://flakehub.com/f/io12/nix-snapd/0.1.29.tar.gz";
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
      # nix shell nixpkgs#home-manager --command sh -c 'home-manager switch -b backup --flake "${HOME}/Zero/nix-config"'
      homeConfigurations = {
        # .iso images
        "nixos@iso-console" = libx.mkHome { hostname = "iso-console"; username = "nixos"; };
        "nixos@iso-desktop" = libx.mkHome { hostname = "iso-desktop"; username = "nixos"; desktop = "pantheon"; };
        # Workstations
        "martin@airmac" = libx.mkHome { hostname = "airmac"; username = "martin"; platform = "aarch64-darwin"; desktop = "aqua";};
        "martin@airnix" = libx.mkHome { hostname = "airnix"; username = "martin"; platform = "aarch64-linux"; desktop = "pantheon"; };
        "martin@p1" = libx.mkHome { hostname = "p1"; username = "martin"; desktop = "pantheon"; };
        "martin@ripper" = libx.mkHome { hostname = "ripper"; username = "martin"; desktop = "pantheon"; };
        "martin@vader" = libx.mkHome { hostname = "vader"; username = "martin"; desktop = "pantheon"; };
        "martin@phasma" = libx.mkHome { hostname = "phasma"; username = "martin"; desktop = "pantheon"; };
        "martin@zed" = libx.mkHome { hostname = "zed"; username = "martin"; desktop = "pantheon"; };
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
        #  - sudo nixos-rebuild switch --flake $HOME/Zero/nix-config
        #  - nix build .#nixosConfigurations.{hostname}.config.system.build.toplevel
        airnix = libx.mkHost { hostname = "airnix"; username = "martin"; desktop = "pantheon"; platform = "aarch64-linux"; };
        p1 = libx.mkHost { hostname = "p1"; username = "martin"; desktop = "pantheon"; };
        ripper = libx.mkHost { hostname = "ripper"; username = "martin"; desktop = "pantheon"; };
        phasma = libx.mkHost { hostname = "phasma"; username = "martin"; desktop = "pantheon"; };
        vader = libx.mkHost { hostname = "vader"; username = "martin"; desktop = "pantheon"; };
        zed = libx.mkHost { hostname = "zed"; username = "martin"; desktop = "pantheon"; };
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
