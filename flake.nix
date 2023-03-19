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
      system = "x86_64-linux";
      # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
      stateVersion = "22.11";
    in
    {
      homeConfigurations = {
        "martin@designare" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit inputs stateVersion;
            desktop = "pantheon";
            hostname = "designare";
            username = "martin";
          };
          modules = [ ./home ];
        };
        "martin@designare-headless" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit inputs stateVersion;
            desktop = null;
            hostname = "designare";
            username = "martin";
          };
          modules = [ ./home ];
        };
        "martin@skull" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit inputs stateVersion;
            desktop = null;
            hostname = "skull";
            username = "martin";
          };
          modules = [ ./home ];
        };
        "martin@z13" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit inputs stateVersion;
            desktop = "pantheon";
            hostname = "z13";
            username = "martin";
          };
          modules = [ ./home ];
        };
      };

      # hostids are generated using: `head -c4 /dev/urandom | od -A none -t x4`
      nixosConfigurations = {
        iso = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs stateVersion;
            hostname = "live";
            hostid = "09ac7fbb";
            desktop = null;
            username = "martin";
          };
          modules = [
            (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
            ./host
          ];
        };
        designare = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs stateVersion;
            hostname = "designare";
            hostid = "8f03b646";
            desktop = "pantheon";
            username = "martin";
          };
          modules = [ ./host ];
        };
        designare-headless = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs stateVersion;
            hostname = "designare";
            hostid = "8f03b646";
            desktop = null;
            username = "martin";
          };
          modules = [ ./host ];
        };
        skull = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs stateVersion;
            hostname = "skull";
            hostid = "be4cb578";
            desktop = null;
            username = "martin";
          };
          modules = [ ./host ];
        };
        z13 = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs stateVersion;
            hostname = "z13";
            hostid = "b28460d8";
            desktop = "pantheon";
            username = "martin";
          };
          modules = [ ./host ];
        };
      };
    };
}
