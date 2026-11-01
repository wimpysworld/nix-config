{
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      coreutils
      gh
      git
      jq
    ];
    text = builtins.readFile ./${name}.sh;
    derivationArgs.postCheck = ''
      export PATH="${
        pkgs.lib.makeBinPath [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.jq
        ]
      }:$PATH"
      ${pkgs.shellcheck}/bin/shellcheck ${./test-${name}.sh}
      ${pkgs.bash}/bin/bash ${./test-${name}.sh} ${./${name}.sh}
    '';
  };
in
lib.mkIf (noughtyLib.userHasTag "developer") { home.packages = [ shellApplication ]; }
