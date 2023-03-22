{
  description = "Wimpy's NixOS and Home Manager Configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    # You can access packages and modules from different nixpkgs revs at the
    # same time. See 'unstable-packages' overlay in 'overlays/default.nix'.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nix-software-center.url = "github:vlinkz/nix-software-center";
  };

  outputs = {
    self,
    nixpkgs,
    disko,
    home-manager,
    nixos-hardware,
    nix-software-center,
    ... } @ inputs:
    let
      inherit (self) outputs;
      forAllSystems = nixpkgs.lib.genAttrs [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
      stateVersion = "22.11";
    in
    rec {
      # Custom packages; acessible via 'nix build', 'nix shell', etc
      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in import ./pkgs { inherit pkgs; }
      );

      # Devshell for bootstrapping; acessible via 'nix develop' or 'nix-shell' (legacy)
      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in import ./shell.nix { inherit pkgs; }
      );

      # Custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs; };

      homeConfigurations = {
        # home-manager switch -b backup --flake $HOME/Zero/nix-config
        "martin@designare" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs stateVersion;
            desktop = "pantheon";
            hostname = "designare";
            username = "martin";
          };
          modules = [ ./home ];
        };

        "martin@designare-headless" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs stateVersion;
            desktop = null;
            hostname = "designare";
            username = "martin";
          };
          modules = [ ./home-manager ];
        };

        "martin@skull" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs stateVersion;
            desktop = null;
            hostname = "skull";
            username = "martin";
          };
          modules = [ ./home-manager ];
        };

        "martin@z13" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs stateVersion;
            desktop = "pantheon";
            hostname = "z13";
            username = "martin";
          };
          modules = [ ./home-manager ];
        };

        "martin@vm" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs stateVersion;
            desktop = "pantheon";
            hostname = "vm";
            username = "martin";
          };
          modules = [ ./home-manager ];
        };
      };

      # hostids are generated using: `head -c4 /dev/urandom | od -A none -t x4`
      nixosConfigurations = {
        # nix build .#nixosConfigurations.iso.config.system.build.isoImage
        iso = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs stateVersion;
            desktop = "pantheon";
            hostname = "live";
            hostid = "09ac7fbb";
            username = "nixos";
          };
          system = "x86_64-linux";
          modules = [
            (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares.nix")
            ./nixos
          ];
        };

        designare = nixpkgs.lib.nixosSystem {
          # sudo nixos-rebuild switch --flake $HOME/Zero/nix-config
          specialArgs = {
            inherit inputs outputs stateVersion;
            desktop = "pantheon";
            hostname = "designare";
            hostid = "8f03b646";
            username = "martin";
          };
          modules = [ ./nixos ];
        };

        designare-headless = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs stateVersion;
            desktop = null;
            hostname = "designare";
            hostid = "8f03b646";
            username = "martin";
          };
          modules = [ ./nixos ];
        };

        skull = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs stateVersion;
            desktop = null;
            hostname = "skull";
            hostid = "be4cb578";
            username = "martin";
          };
          modules = [ ./nixos ];
        };

        z13 = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs stateVersion;
            desktop = "pantheon";
            hostname = "z13";
            hostid = "b28460d8";
            username = "martin";
          };
          modules = [ ./nixos ];
        };

        vm = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs stateVersion;
            desktop = "pantheon";
            hostname = "vm";
            hostid = "37f0bf56";
            username = "martin";
          };
          modules = [ ./nixos ];
        };
      };
    };
}
