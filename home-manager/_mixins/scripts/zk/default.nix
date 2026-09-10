{
  config,
  lib,
  pkgs,
  ...
}:
let
  shellApplication = pkgs.writeShellApplication {
    name = "zk";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.fzf
    ];
    runtimeEnv = {
      FRESH = lib.getExe config.programs.fresh-editor.package;
      ZK_NATIVE = lib.getExe pkgs.zk;
    };
    text = builtins.readFile ./zk.sh;
  };
in
{
  programs.zk.package = pkgs.symlinkJoin {
    name = "zk-terminal-${pkgs.zk.version}";
    paths = [
      shellApplication
      pkgs.zk
    ];
    inherit (pkgs.zk) meta;
  };
}
