{ inputs, outputs, stateVersion, username, ... }: {
  # Helper function for generating home-manager configs
  mkHome = { hostname, user ? username, desktop ? null }: inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
    extraSpecialArgs = {
      inherit inputs outputs desktop hostname stateVersion;
      username = user;
    };
    modules = [ ../home-manager ];
  };

  # Helper function for generating host configs
  mkHost = { hostname, desktop ? null, pkgsInput ? inputs.nixpkgs }: pkgsInput.lib.nixosSystem {
    specialArgs = {
      inherit inputs outputs desktop hostname username stateVersion;
    };
    modules = [ ../nixos ];
  };

  forAllSystems = inputs.nixpkgs.lib.genAttrs [
    "aarch64-linux"
    "i686-linux"
    "x86_64-linux"
    "aarch64-darwin"
    "x86_64-darwin"
  ];
}
