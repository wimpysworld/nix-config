{
  darwinStateVersion,
  inputs,
  outputs,
  stateVersion,
  users ? { },
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

      isoDefaults = lib.optionalAttrs (lib.elem "iso" (entry.tags or [ ])) {
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

      # Look up user-level metadata from the users table.
      userEntry = users.${merged.username} or { };
    in
    merged // { inherit userEntry; };

  # Predicate functions for filtering registry entries
  isLinuxEntry = e: lib.hasSuffix "-linux" e.platform;
  isDarwinEntry = e: lib.hasSuffix "-darwin" e.platform;
  isISOEntry = e: lib.elem "iso" (e.tags or [ ]);
  isHomeOnlyEntry =
    e:
    let
      tags = e.tags or [ ];
    in
    builtins.elem "wsl" tags || builtins.elem "lima" tags || builtins.elem "steamdeck" tags;
in
rec {
  # Export predicate functions for use in flake.nix
  inherit
    isLinuxEntry
    isDarwinEntry
    isISOEntry
    isHomeOnlyEntry
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

      # CSS rgba() helper for use in GTK CSS, avizo, wlogout, etc.
      mkRgba =
        colorName: alpha:
        let
          rgb = palette.${colorName}.rgb;
        in
        "rgba(${toString rgb.r}, ${toString rgb.g}, ${toString rgb.b}, ${alpha})";

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
        mkRgba
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
      hostGpuCompute ? { },
      hostTags ? [ ],
      hostDisplays ? [ ],
      userTags ? [ ],
    }:
    let
      # Generate the Catppuccin palette for this system
      catppuccinPalette = mkCatppuccinPalette { system = platform; };
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.${platform};
      extraSpecialArgs = {
        inherit
          inputs
          outputs
          stateVersion
          catppuccinPalette
          ;
      };
      modules = [
        ../home-manager
        {
          noughty.host = {
            name = hostname;
            kind = hostKind;
            platform = platform;
            formFactor = hostFormFactor;
            gpu = {
              vendors = hostGpuVendors;
              compute = hostGpuCompute;
            };
            tags = hostTags;
            displays = hostDisplays;
            desktop = desktop;
          };
          noughty.user.name = username;
          noughty.user.tags = userTags;
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
      hostGpuCompute ? { },
      hostTags ? [ ],
      hostDisplays ? [ ],
      userTags ? [ ],
    }:
    let
      # Generate the Catppuccin palette for this system
      catppuccinPalette = mkCatppuccinPalette { system = platform; };
    in
    inputs.nixpkgs.lib.nixosSystem {
      system = platform;
      specialArgs = {
        inherit
          inputs
          outputs
          stateVersion
          catppuccinPalette
          ;
      };
      # Include the ISO installer module when the "iso" tag is present.
      modules =
        let
          cd-dvd = inputs.nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix";
        in
        [
          ../nixos
          ../nixos/${hostname}
          {
            noughty.host = {
              name = hostname;
              kind = hostKind;
              platform = platform;
              formFactor = hostFormFactor;
              gpu = {
                vendors = hostGpuVendors;
                compute = hostGpuCompute;
              };
              tags = hostTags;
              displays = hostDisplays;
              desktop = desktop;
            };
            noughty.user.name = username;
            noughty.user.tags = userTags;
          }
        ]
        ++ inputs.nixpkgs.lib.optionals (lib.elem "iso" hostTags) [ cd-dvd ];
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
      hostGpuCompute ? { },
      hostTags ? [ ],
      hostDisplays ? [ ],
      userTags ? [ ],
    }:
    let
      # Generate the Catppuccin palette for this system
      catppuccinPalette = mkCatppuccinPalette { system = platform; };
      # nix-darwin uses an integer stateVersion (e.g. 5), not a string like NixOS
      stateVersion = darwinStateVersion;
    in
    inputs.nix-darwin.lib.darwinSystem {
      system = platform;
      specialArgs = {
        inherit
          inputs
          outputs
          stateVersion
          catppuccinPalette
          ;
      };
      modules = [
        ../darwin
        ../darwin/${hostname}
        {
          noughty.host = {
            name = hostname;
            kind = hostKind;
            platform = platform;
            formFactor = hostFormFactor;
            gpu = {
              vendors = hostGpuVendors;
              compute = hostGpuCompute;
            };
            tags = hostTags;
            displays = hostDisplays;
            desktop = desktop;
          };
          noughty.user.name = username;
          noughty.user.tags = userTags;
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
      hostGpuCompute = (resolved.gpu or { }).compute or { };
      hostTags = resolved.tags or [ ];
      hostDisplays = resolved.displays or [ ];
      userTags = (resolved.userEntry or { }).tags or [ ];
    };

  # Generate configurations by filtering with a predicate function
  generateConfigs =
    predicate: systems:
    let
      filteredSystems = lib.filterAttrs (_name: entry: predicate entry) systems;
    in
    lib.mapAttrs (name: entry: mkSystemConfig name entry) filteredSystems;
}
