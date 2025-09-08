{
  inputs,
  outputs,
  stateVersion,
  ...
}:
rec {
  # Helper function for generating home-manager configs
  mkHome =
    {
      hostname,
      username ? "martin",
      desktop ? null,
      platform ? "x86_64-linux",
    }:
    let
      isISO = builtins.substring 0 4 hostname == "iso-";
      isInstall = !isISO;
      isLaptop =
        hostname != "vader"
        && hostname != "phasma"
        && hostname != "revan"
        && hostname != "malak"
        && hostname != "maul";
      isLima = hostname == "blackace" || hostname == "defender" || hostname == "fighter";
      isWorkstation = builtins.isString desktop;
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.${platform};
      extraSpecialArgs = {
        inherit
          inputs
          outputs
          desktop
          hostname
          username
          stateVersion
          isInstall
          isLaptop
          isLima
          isISO
          isWorkstation
          ;
      };
      modules = [ ../home-manager ];
    };

  # Helper function for generating NixOS configs
  mkNixos =
    {
      hostname,
      username ? "martin",
      desktop ? null,
      platform ? "x86_64-linux",
    }:
    let
      isISO = builtins.substring 0 4 hostname == "iso-";
      isInstall = !isISO;
      isLaptop =
        hostname != "vader"
        && hostname != "phasma"
        && hostname != "revan"
        && hostname != "malak"
        && hostname != "maul";
      isWorkstation = builtins.isString desktop;
      tailNet = "drongo-gamma.ts.net";
    in
    inputs.nixpkgs.lib.nixosSystem {
      system = platform;
      specialArgs = {
        inherit
          inputs
          outputs
          desktop
          hostname
          username
          stateVersion
          isInstall
          isISO
          isLaptop
          isWorkstation
          tailNet
          ;
      };
      # If the hostname starts with "iso-", generate an ISO image
      modules =
        let
          cd-dvd =
            if (desktop == null) then
              inputs.nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            else
              inputs.nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares.nix";
        in
        [ ../nixos ] ++ inputs.nixpkgs.lib.optionals isISO [ cd-dvd ];
    };

  mkDarwin =
    {
      desktop ? "aqua",
      hostname,
      username ? "martin",
      platform ? "aarch64-darwin",
    }:
    let
      isISO = false;
      isInstall = true;
      isLaptop = true;
      isWorkstation = true;
    in
    inputs.nix-darwin.lib.darwinSystem {
      system = platform;
      specialArgs = {
        inherit
          inputs
          outputs
          desktop
          hostname
          username
          isInstall
          isISO
          isLaptop
          isWorkstation
          ;
      };
      modules = [
        ../darwin
      ];
    };

  forAllSystems = inputs.nixpkgs.lib.genAttrs [
    "aarch64-linux"
    "x86_64-linux"
    "aarch64-darwin"
    "x86_64-darwin"
  ];

  # Helper function to create system configurations based on type
  mkSystemConfig =
    name: config: typeDefaults:
    let
      # Get type-specific defaults
      defaults = typeDefaults.${config.type} or { };
      # Merge system config with defaults
      finalConfig = defaults // config;
      # Filter config to only include parameters expected by helper functions
      helperConfig = {
        hostname = name;
        username = finalConfig.username;
        desktop = finalConfig.desktop;
        platform = finalConfig.platform;
      };
    in
    helperConfig;

  # Generate configurations for each type
  generateConfigs =
    configType: systems: typeDefaults:
    let
      filteredSystems = inputs.nixpkgs.lib.filterAttrs (name: config: config.type == configType) systems;
    in
    inputs.nixpkgs.lib.mapAttrs (name: config: mkSystemConfig name config typeDefaults) filteredSystems;
}
