{
  inputs,
  outputs,
  stateVersion,
  ...
}:
let
  lib = inputs.nixpkgs.lib;

  # Resolve a registry entry by merging four layers (later wins):
  # 1. baseline username
  # 2. kind + OS derived desktop
  # 3. iso implicit defaults
  # 4. explicit entry values
  resolveEntry =
    name: entry:
    let
      isDarwin = lib.hasSuffix "-darwin" entry.platform;

      kDefaults = {
        desktop =
          {
            computer = if isDarwin then "aqua" else "hyprland";
            server = null;
            vm = null;
            container = null;
          }
          .${entry.kind};
      };

      isoDefaults = lib.optionalAttrs (entry.iso or false) {
        desktop = null;
        username = "nixos";
      };

      merged = {
        username = "martin";
      }
      // kDefaults
      // isoDefaults
      // entry
      // {
        name = name;
      };
    in
    merged;

  # Predicate functions for filtering registry entries
  isLinuxEntry = e: lib.hasSuffix "-linux" e.platform;
  isDarwinEntry = e: lib.hasSuffix "-darwin" e.platform;
  isISOEntry = e: e.iso or false;
  isWSLEntry = e: builtins.elem "wsl" (e.tags or [ ]);
  isLimaEntry = e: builtins.elem "lima" (e.tags or [ ]);
  isGamingEntry = e: builtins.elem "gaming" (e.tags or [ ]);
in
rec {
  # Export predicate functions for use in flake.nix
  inherit
    isLinuxEntry
    isDarwinEntry
    isISOEntry
    isWSLEntry
    isLimaEntry
    isGamingEntry
    ;

  # Generate Catppuccin palette with helper functions
  # This reads the palette JSON and provides convenient colour access functions
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

      # VT colour mapping (16 ANSI colours: 0-15)
      # Standard ANSI colours followed by bright variants
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
      hostKind ? "computer",
      hostFormFactor ? null,
      hostGpuVendors ? [ ],
      hostTags ? [ ],
      hostIsIso ? false,
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
          hostname
          stateVersion
          isInstall
          isLaptop
          isLima
          isISO
          isServer
          isWorkstation
          catppuccinPalette
          platform
          hostKind
          hostFormFactor
          hostGpuVendors
          hostTags
          hostIsIso
          ;
      };
      modules = [
        ../home-manager
        {
          noughty.host.desktop = desktop;
          noughty.user.name = username;
        }
      ];
    };

  # Helper function for generating NixOS configs
  mkNixos =
    {
      hostname,
      username ? "martin",
      desktop ? null,
      platform ? "x86_64-linux",
      hostKind ? "computer",
      hostFormFactor ? null,
      hostGpuVendors ? [ ],
      hostTags ? [ ],
      hostIsIso ? false,
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
          hostname
          stateVersion
          isInstall
          isISO
          isLaptop
          isServer
          isWorkstation
          tailNet
          catppuccinPalette
          platform
          hostKind
          hostFormFactor
          hostGpuVendors
          hostTags
          hostIsIso
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
        [
          ../nixos
          {
            noughty.host.desktop = desktop;
            noughty.user.name = username;
          }
        ]
        ++ inputs.nixpkgs.lib.optionals isISO [ cd-dvd ];
    };

  mkDarwin =
    {
      desktop ? "aqua",
      hostname,
      username ? "martin",
      platform ? "aarch64-darwin",
      hostKind ? "computer",
      hostFormFactor ? null,
      hostGpuVendors ? [ ],
      hostTags ? [ ],
      hostIsIso ? false,
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
          hostname
          isInstall
          isISO
          isLaptop
          isServer
          isWorkstation
          catppuccinPalette
          platform
          hostKind
          hostFormFactor
          hostGpuVendors
          hostTags
          hostIsIso
          ;
      };
      modules = [
        ../darwin
        {
          noughty.host.desktop = desktop;
          noughty.user.name = username;
        }
      ];
    };

  forAllSystems = inputs.nixpkgs.lib.genAttrs [
    "aarch64-linux"
    "x86_64-linux"
    "aarch64-darwin"
  ];

  # Resolve a registry entry and produce the helperConfig attrset
  # that mkNixos/mkHome/mkDarwin expect.
  mkSystemConfig =
    name: entry:
    let
      resolved = resolveEntry name entry;
    in
    {
      hostname = name;
      username = resolved.username;
      desktop = resolved.desktop or null;
      platform = resolved.platform;
      hostKind = resolved.kind;
      hostFormFactor = resolved.formFactor or null;
      hostGpuVendors = (resolved.gpu or { }).vendors or [ ];
      hostTags = resolved.tags or [ ];
      hostIsIso = resolved.iso or false;
    };

  # Generate configurations by filtering with a predicate function
  generateConfigs =
    predicate: systems:
    let
      filteredSystems = lib.filterAttrs (_name: entry: predicate entry) systems;
    in
    lib.mapAttrs (name: entry: mkSystemConfig name entry) filteredSystems;
}
