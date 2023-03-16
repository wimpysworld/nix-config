{
  description = "Wimpy's NixOS and Home Manager Configuration";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = {
    self,
    nixpkgs,
    disko,
    nixos-generators,
    nixos-hardware,
    home-manager,
    ... } @ inputs:
    let
      inherit (self) outputs;
      system = "x86_64-linux";
    in
    {
      defaultPackage.x86_64-linux = home-manager.defaultPackage."x86_64-linux";

      homeConfigurations = {
        "martin@designare" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit inputs outputs;
            desktop = "pantheon";
            hostname = "designare";
            username = "martin";
          };
          modules = [ ./home ];
        };
        "martin@skull" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit inputs outputs;
            desktop = null;
            hostname = "skull";
            username = "martin";
          };
          modules = [ ./home ];
        };
        "martin@z13" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit inputs outputs;
            desktop = "pantheon";
            hostname = "z13";
            username = "martin";
          };
          modules = [ ./home ];
        };
      };

      # hostids are generated using: `head -c4 /dev/urandom | od -A none -t x4`
      nixosConfigurations = {
        iso = nixos-generators.nixosGenerate {
          inherit system;
          format = "iso";
          specialArgs = {
            inherit inputs outputs;
            hostname = "generic";
            hostid = "d5e8bae8";
            desktop = "mate";
            username = "nix";
          };
          modules = [ ./host ];
        };
        designare = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs outputs;
            hostname = "designare";
            hostid = "8f03b646";
            desktop = "pantheon";
            username = "martin";
          };
          modules = [
            ./host
            nixos-hardware.nixosModules.common-cpu-intel
            nixos-hardware.nixosModules.common-gpu-amd
            nixos-hardware.nixosModules.common-gpu-intel
            nixos-hardware.nixosModules.common-gpu-nvidia
            nixos-hardware.nixosModules.common-pc
            nixos-hardware.nixosModules.common-pc-ssd
          ];
        };
        skull = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs outputs;
            hostname = "skull";
            hostid = "be4cb578";
            desktop = null;
            username = "martin";
          };
          modules = [
            ./host
            nixos-hardware.nixosModules.common-cpu-intel
            nixos-hardware.nixosModules.common-pc
            nixos-hardware.nixosModules.common-pc-ssd
          ];
        };
        z13 = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs outputs;
            hostname = "z13";
            hostid = "b28460d8";
            desktop = "pantheon";
            username = "martin";
          };
          modules = [
            ./host
            nixos-hardware.nixosModules.lenovo-thinkpad-z13
          ];
        };
      };
    };
}
