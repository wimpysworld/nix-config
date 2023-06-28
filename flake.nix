{
  description = "Wimpy's NixOS and Home Manager Configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    # You can access packages and modules from different nixpkgs revs at the
    # same time. See 'unstable-packages' overlay in 'overlays/default.nix'.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-23.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = {
    self,
    nixpkgs,
    disko,
    home-manager,
    nixos-hardware,
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
      stateVersion = "23.05";
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
          modules = [ ./home-manager ];
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

        "martin@ripper" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs stateVersion;
            desktop = "pantheon";
            hostname = "ripper";
            username = "martin";
          };
          modules = [ ./home-manager ];
        };

        "martin@trooper" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs stateVersion;
            desktop = "pantheon";
            hostname = "trooper";
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

        "martin@zed" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs stateVersion;
            desktop = "pantheon";
            hostname = "zed";
            username = "martin";
          };
          modules = [ ./home-manager ];
        };

        "martin@phony" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs stateVersion;
            desktop = "pantheon";
            hostname = "phony";
            username = "martin";
          };
          modules = [ ./home-manager ];
        };
      };

      nixosConfigurations = {
        # nix build .#nixosConfigurations.iso.config.system.build.isoImage
        iso = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs stateVersion;
            desktop = "pantheon";
            hostname = "live";
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
            username = "martin";
          };
          modules = [ ./nixos ];
        };

        designare-headless = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs stateVersion;
            desktop = null;
            hostname = "designare";
            username = "martin";
          };
          modules = [ ./nixos ];
        };

        skull = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs stateVersion;
            desktop = null;
            hostname = "skull";
            username = "martin";
          };
          modules = [ ./nixos ];
        };

        trooper = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs stateVersion;
            desktop = "pantheon";
            hostname = "trooper";
            username = "martin";
          };
          modules = [ ./nixos ];
        };

        zed = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs stateVersion;
            desktop = "pantheon";
            hostname = "zed";
            username = "martin";
          };
          modules = [ ./nixos ];
        };

        vm = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs stateVersion;
            desktop = "pantheon";
            hostname = "vm";
            username = "martin";
          };
          modules = [ ./nixos ];
        };
      };
    };
}
