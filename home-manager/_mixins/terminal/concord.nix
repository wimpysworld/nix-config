{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  system = pkgs.stdenv.hostPlatform.system;

  # Crane vendors Cargo git dependencies with builtins.fetchGit at evaluation
  # time, which clones every ref and every submodule before any derivation
  # exists, so the binary cache cannot help. Concord depends on thorvg-rs,
  # whose submodules pull a ThorVG fork and picolibc with hundreds of tags and
  # over 750 MB of history. Giving crane an output hash switches that fetch to
  # a shallow, fixed-output fetchgit at build time.
  #
  # When concord moves thorvg-rs to a new revision, evaluation fails with the
  # new source string. Compute its hash with:
  #   nix-prefetch-git --url <url> --rev <rev> --fetch-submodules
  cargoGitOutputHashes = {
    "git+https://github.com/chojs23/thorvg-rs.git?rev=2548bdbb1487cf473d2c1fe580891b57d973f0dc#2548bdbb1487cf473d2c1fe580891b57d973f0dc" =
      "sha256-ECSuq6QQC8myTk2sTyQw0vHWrm7ab4psXVgsx/uAPbA=";
  };

  cargoLock = builtins.fromTOML (builtins.readFile "${inputs.concord}/Cargo.lock");
  cargoGitSources = lib.unique (
    map (p: p.source) (builtins.filter (p: lib.hasPrefix "git+" (p.source or "")) cargoLock.package)
  );
  outputHashes = lib.genAttrs cargoGitSources (
    source:
    cargoGitOutputHashes.${source}
      or (throw "concord: no output hash for Cargo git dependency ${source}; see home-manager/_mixins/terminal/concord.nix")
  );

  # Rebuild the crane library that concord's flake uses, with the same pinned
  # Rust toolchain, so only the vendoring step changes. The toolchain version
  # is read from concord's flake.nix to stay aligned with upstream.
  concordFlakeNix = builtins.readFile "${inputs.concord}/flake.nix";
  rustToolchainVersion =
    let
      match = builtins.match ''.*rust-bin\.stable\."([0-9.]+)"\.default.*'' concordFlakeNix;
    in
    if match == null then
      throw "concord: cannot find the pinned rust-bin.stable version in ${inputs.concord}/flake.nix"
    else
      builtins.head match;
  rustBin = inputs.rust-overlay.lib.mkRustBin { } pkgs.unstable;
  craneLib =
    (inputs.concord.inputs.crane.mkLib pkgs.unstable).overrideToolchain
      rustBin.stable.${rustToolchainVersion}.default;
  pinnedCraneLib = craneLib // {
    vendorCargoDeps = args: craneLib.vendorCargoDeps (args // { inherit outputHashes; });
  };

  concordPackage = inputs.concord.packages.${system}.default.override {
    craneLib = pinnedCraneLib;
    stdenv = pkgs.unstable.stdenv // {
      isLinux = pkgs.unstable.stdenv.hostPlatform.isLinux;
    };
  };
in
{
  config = lib.mkIf (host.is.linux && host.is.workstation && system == "x86_64-linux") {
    home.packages = [
      concordPackage
    ];
  };
}
