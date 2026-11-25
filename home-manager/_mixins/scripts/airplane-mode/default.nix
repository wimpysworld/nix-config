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
    runtimeInputs = with pkgs; [
      coreutils
      fyi
      jq
      util-linux
    ];
    text = builtins.readFile ./${name}.sh;
    derivationArgs.postCheck = ''
      PATH=${
        lib.makeBinPath [
          pkgs.coreutils
          pkgs.jq
        ]
      } \
        ${pkgs.python3}/bin/python3 ${./test-airplane-mode.py} \
        ${./airplane-mode.sh} ${pkgs.bash}/bin/bash
    '';
  };
in
lib.mkIf (host.is.linux && host.is.workstation) {
  home.packages = [ shellApplication ];
}
