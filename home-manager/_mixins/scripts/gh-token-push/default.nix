{
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  systems = builtins.fromTOML (builtins.readFile ../../../../lib/registry-systems.toml);
  # `--all` targets every registry host with `kind = "server"`.
  servers = lib.attrNames (lib.filterAttrs (_: system: (system.kind or null) == "server") systems);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      coreutils
      gh
      gnused
      openssh
    ];
    runtimeEnv.GH_TOKEN_PUSH_SERVERS = lib.concatStringsSep " " servers;
    text = builtins.readFile ./${name}.sh;
  };
in
# A work policy forbids SSH from Chainguard machines, so hosts with the `cg`
# tag never get this script.
lib.mkIf (!noughtyLib.hostHasTag "cg") { home.packages = [ shellApplication ]; }
