{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [ fuzzel ];
    text = builtins.readFile ./${name}.sh;
    derivationArgs.postCheck = ''
      ${pkgs.python3}/bin/python3 ${./test-session-menu.py} \
        ${./fuzzel-session-menu.sh} ${pkgs.bash}/bin/bash
    '';
  };
in
lib.mkIf (host.is.linux && host.is.workstation) {
  home.packages = [ shellApplication ];
}
