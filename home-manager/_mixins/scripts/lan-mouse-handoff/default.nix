{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  name = builtins.baseNameOf (builtins.toString ./.);
  wayfireIpc = import ../../desktop/compositor/components/compositor-query/wayfire-ipc.nix pkgs;
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    # mmsg resolves from the session PATH, so it always matches the
    # running Mango instance.
    runtimeInputs = [
      wayfireIpc
    ]
    ++ (with pkgs; [
      coreutils
      findutils
      jq
      openssh
    ]);
    text =
      builtins.readFile ../../desktop/compositor/components/compositor-query/compositor-query.sh
      + lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ./${name}.sh);
  };
in
lib.mkIf (noughtyLib.isUser [ "martin" ] && host.is.workstation && host.is.linux) {
  home.packages = [ shellApplication ];
}
