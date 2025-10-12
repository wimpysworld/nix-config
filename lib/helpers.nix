{
  inputs,
  outputs,
  stateVersion,
  ...
}:
rec {
  # Generate Catppuccin palette with helper functions
  # This reads the palette JSON and provides convenient color access functions
  mkCatppuccinPalette =
    {
      flavor ? "mocha",
      accent ? "blue",
      system ? "x86_64-linux",
    }:
    let
      paletteJson = builtins.fromJSON (
        builtins.readFile "${inputs.catppuccin.packages.${system}.palette}/palette.json"
      );
      palette = paletteJson.${flavor}.colors;

      # Helper functions for palette access
      getColor = colorName: palette.${colorName}.hex;
      getRGB = colorName: palette.${colorName}.rgb;
      getHSL = colorName: palette.${colorName}.hsl;

      # Hyprland-specific helper that removes # from hex colors
      getHyprlandColor = colorName: builtins.substring 1 (-1) palette.${colorName}.hex;

      # Determine if this is a dark theme
      isDark = flavor != "latte";
      isDarkAsIntString = if isDark then "1" else "0";
      themeShade = if isDark then "-Dark" else "-Light";
      preferShade = if isDark then "prefer-dark" else "prefer-light";

      # VT color mapping (16 ANSI colors: 0-15)
      # Standard ANSI colors followed by bright variants
      # Note: Index 0 is used as default background, so it must be "base"
      vtColorMap = [
        "base" # 0: black (also used as default background)
        "red" # 1: red
        "green" # 2: green
        "yellow" # 3: yellow
        "blue" # 4: blue
        "pink" # 5: magenta
        "teal" # 6: cyan
        "subtext0" # 7: light grey
        "surface1" # 8: dark grey (bright black)
        "red" # 9: bright red
        "green" # 10: bright green
        "yellow" # 11: bright yellow
        "blue" # 12: bright blue
        "pink" # 13: bright magenta
        "teal" # 14: bright cyan
        "text" # 15: white
      ];
    in
    {
      inherit
        getColor
        getRGB
        getHSL
        getHyprlandColor
        isDark
        isDarkAsIntString
        themeShade
        preferShade
        vtColorMap
        ;
      colors = palette;
      accent = accent;
      flavor = flavor;
    };

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
      isServer = desktop == null && !isLima && !isISO;

      # Generate the Catppuccin palette for this system
      catppuccinPalette = mkCatppuccinPalette { system = platform; };
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
          isServer
          isWorkstation
          catppuccinPalette
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
      isLima = hostname == "blackace" || hostname == "defender" || hostname == "fighter";
      isWorkstation = builtins.isString desktop;
      isServer = desktop == null && !isLima && !isISO;
      tailNet = "drongo-gamma.ts.net";

      # Generate the Catppuccin palette for this system
      catppuccinPalette = mkCatppuccinPalette { system = platform; };
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
          isServer
          isWorkstation
          tailNet
          catppuccinPalette
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
      isServer = false;

      # Generate the Catppuccin palette for this system
      catppuccinPalette = mkCatppuccinPalette { system = platform; };
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
          isServer
          isWorkstation
          catppuccinPalette
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
