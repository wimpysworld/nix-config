{
  description = "Wimpy's NixOS and Home Manager Configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    # You can access packages and modules from different nixpkgs revs at the
    # same time. See 'unstable-packages' overlay in 'overlays/default.nix'.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-23.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };
  outputs = {
    self,
    disko,
    home-manager,
    nixos-hardware,
    nixpkgs,
    ... } @ inputs:
  let
    inherit (self) outputs;
    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    stateVersion = "23.05";
    libx = import ./lib { inherit inputs outputs stateVersion; };
  in {
    # home-manager switch -b backup --flake $HOME/Zero/nix-config
    # nix build .#homeConfigurations."martin@ripper".activationPackage
    homeConfigurations = {
      # .iso images
      "martin@iso-console" = libx.mkHome { hostname = "iso-console"; username = "nixos"; };
      "martin@iso-desktop" = libx.mkHome { hostname = "iso-desktop"; username = "nixos"; desktop = "pantheon"; };
      # Workstations
      "martin@designare" = libx.mkHome { hostname = "designare"; username = "martin"; desktop = "pantheon"; };
      "martin@micropc"   = libx.mkHome { hostname = "micropc";   username = "martin"; desktop = "pantheon"; };
      "martin@p1"    =     libx.mkHome { hostname = "p1";        username = "martin"; desktop = "pantheon"; };
      "martin@p2-max"    = libx.mkHome { hostname = "p2-max";    username = "martin"; desktop = "pantheon"; };
      "martin@ripper"    = libx.mkHome { hostname = "ripper";    username = "martin"; desktop = "pantheon"; };
      "martin@trooper"   = libx.mkHome { hostname = "trooper";   username = "martin"; desktop = "pantheon"; };
      "martin@vm"        = libx.mkHome { hostname = "vm";        username = "martin"; desktop = "pantheon"; };
      "martin@zed"       = libx.mkHome { hostname = "zed";       username = "martin"; desktop = "pantheon"; };
      # Servers
      "martin@brix"      = libx.mkHome { hostname = "brix";      username = "martin"; };
      "martin@skull"     = libx.mkHome { hostname = "skull";     username = "martin"; };
      "martin@vm-mini"   = libx.mkHome { hostname = "vm-mini";   username = "martin"; };
    };
    nixosConfigurations = {
      # .iso images
      #  - nix build .#nixosConfigurations.{iso-console|iso-desktop}.config.system.build.isoImage
      iso-console = libx.mkHost { hostname = "iso-console"; username = "nixos"; installer = nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"; };
      iso-desktop = libx.mkHost { hostname = "iso-desktop"; username = "nixos"; installer = nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares.nix"; desktop = "pantheon"; };
      # Workstations
      #  - sudo nixos-rebuild switch --flake $HOME/Zero/nix-config
      #  - nix build .#nixosConfigurations.ripper.config.system.build.toplevel
      designare = libx.mkHost { hostname = "designare"; username = "martin"; desktop = "pantheon"; };
      p1        = libx.mkHost { hostname = "p1";        username = "martin"; desktop = "pantheon"; };
      p2-max    = libx.mkHost { hostname = "p2-max";    username = "martin"; desktop = "pantheon"; };
      micropc   = libx.mkHost { hostname = "micropc";   username = "martin"; desktop = "pantheon"; };
      ripper    = libx.mkHost { hostname = "ripper";    username = "martin"; desktop = "pantheon"; };
      trooper   = libx.mkHost { hostname = "trooper";   username = "martin"; desktop = "pantheon"; };
      vm        = libx.mkHost { hostname = "vm";        username = "martin"; desktop = "pantheon"; };
      zed       = libx.mkHost { hostname = "zed";       username = "martin"; desktop = "pantheon"; };
      # Servers
      brix      = libx.mkHost { hostname = "brix";      username = "martin"; };
      skull     = libx.mkHost { hostname = "skull";     username = "martin"; };
      vm-mini   = libx.mkHost { hostname = "vm-mini";   username = "martin"; };
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
