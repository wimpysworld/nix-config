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
  wayfireIpc = import ../lan-mouse-warp/wayfire-ipc.nix pkgs;
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    # hyprctl and mmsg resolve from the session PATH, so each always
    # matches the running Hyprland or MangoWM instance.
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
      builtins.readFile ../lan-mouse-warp/compositor-query.sh
      + lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ./${name}.sh);
  };
in
lib.mkIf (noughtyLib.isUser [ "martin" ] && host.is.workstation && host.is.linux) {
  home.packages = [ shellApplication ];
}
