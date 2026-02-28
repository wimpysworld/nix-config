{
  description = "Wimpy's NixOS, nix-darwin and Home Manager Configuration";
  inputs = {
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-25.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # Shared transitive inputs; most flake-utils and blueprint depend on nix-systems/default.
    systems.url = "github:nix-systems/default";
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    llm-agents.url = "github:numtide/llm-agents.nix";
    llm-agents.inputs.nixpkgs.follows = "nixpkgs-unstable";
    llm-agents.inputs.treefmt-nix.follows = "direnv-instant/treefmt-nix";
    llm-agents.inputs.blueprint.inputs.systems.follows = "systems";
    bzmenu.url = "https://github.com/e-tho/bzmenu/archive/refs/tags/v0.3.0.tar.gz";
    bzmenu.inputs.nixpkgs.follows = "nixpkgs";
    bzmenu.inputs.rust-overlay.follows = "rust-overlay";
    bzmenu.inputs.flake-utils.follows = "flake-utils";
    iwmenu.url = "https://github.com/e-tho/iwmenu/archive/refs/tags/v0.3.0.tar.gz";
    iwmenu.inputs.nixpkgs.follows = "nixpkgs";
    iwmenu.inputs.rust-overlay.follows = "rust-overlay";
    iwmenu.inputs.flake-utils.follows = "flake-utils";
    pwmenu.url = "https://github.com/e-tho/pwmenu/archive/refs/tags/v0.3.0.tar.gz";
    pwmenu.inputs.nixpkgs.follows = "nixpkgs";
    pwmenu.inputs.rust-overlay.follows = "rust-overlay";
    pwmenu.inputs.flake-utils.follows = "flake-utils";
    catppuccin.url = "https://github.com/catppuccin/nix/archive/refs/tags/v25.11.tar.gz";
    catppuccin.inputs.nixpkgs.follows = "nixpkgs";
    direnv-instant.url = "github:Mic92/direnv-instant";
    direnv-instant.inputs.nixpkgs.follows = "nixpkgs";
    direnv-instant.inputs.flake-parts.follows = "flake-parts";
    disko.url = "https://flakehub.com/f/nix-community/disko/1.13.0.tar.gz";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    kolide-launcher.url = "github:/kolide/nix-agent/main";
    kolide-launcher.inputs.flake-compat.follows = "determinate/nix/git-hooks-nix/flake-compat";
    kolide-launcher.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
    nix-flatpak.url = "https://flakehub.com/f/gmodena/nix-flatpak/0.6.0.tar.gz";
    mac-app-util.url = "github:hraban/mac-app-util";
    mac-app-util.inputs.nixpkgs.follows = "nixpkgs";
    mac-app-util.inputs.cl-nix-lite.inputs.nixpkgs.follows = "nixpkgs";
    mac-app-util.inputs.cl-nix-lite.inputs.systems.follows = "systems";
    mac-app-util.inputs.cl-nix-lite.inputs.flake-parts.follows = "flake-parts";
    mac-app-util.inputs.cl-nix-lite.inputs.treefmt-nix.follows = "mac-app-util/treefmt-nix";
    # Do not follow root flake-utils here; mac-app-util needs darwin-only systems
    # from nix-systems/default-darwin, while our root flake-utils uses nix-systems/default.
    # Sharing flake-utils would make eachDefaultSystem include Linux, causing dockutil
    # (darwin-only) to be evaluated on Linux.
    #mac-app-util.inputs.flake-utils.follows = "flake-utils";
    mac-app-util.inputs.treefmt-nix.follows = "direnv-instant/treefmt-nix";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    vscode-server.inputs.nixpkgs.follows = "nixpkgs";
    vscode-server.inputs.flake-utils.follows = "flake-utils";
    xdg-override.url = "github:koiuo/xdg-override";
    xdg-override.inputs.nixpkgs.follows = "nixpkgs";
    xdg-override.inputs.flake-parts.follows = "flake-parts";
  };
  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      stateVersion = "25.11";
      darwinStateVersion = 6;
      users = builtins.fromTOML (builtins.readFile ./lib/registry-users.toml);
      systems = builtins.fromTOML (builtins.readFile ./lib/registry-systems.toml);

      builder = import ./lib {
        inherit
          inputs
          outputs
          stateVersion
          darwinStateVersion
          users
          ;
      };
    in
    {
      lib = builder;

      nixosConfigurations = builder.mkAllNixos systems;
      darwinConfigurations = builder.mkAllDarwin systems;
      homeConfigurations = builder.mkAllHomes systems;

      overlays = import ./overlays { inherit inputs; };
      nixosModules = import ./modules/nixos;

      packages = builder.mkPackages {
        overlays = self.overlays;
        localPackagesPath = ./pkgs;
        linuxOnlyFlakeInputs = {
          inherit (inputs)
            bzmenu
            iwmenu
            pwmenu
            ;
        };
      };

      formatter = builder.forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      devShells = builder.mkDevShells {
        overlays = self.overlays;
        shellPackages =
          p: with p; [
            deadnix
            git
            home-manager
            jq
            just
            micro
            nh
            nixfmt-tree
            nixfmt
            nix-output-monitor
            openssh
            sops
            statix
            taplo
          ];
        extraFlakeInputs = with inputs; [
          determinate
          disko
          fh
        ];
      };
    };
}
