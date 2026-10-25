{ pkgs, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      coreutils
      openssh
      rsync
    ];
    text = builtins.readFile ./${name}.sh;
    derivationArgs.postCheck = ''
      export PATH="${pkgs.lib.makeBinPath [ pkgs.coreutils ]}:$PATH"
      export TEST_FISH=${pkgs.fish}/bin/fish
      ${pkgs.shellcheck}/bin/shellcheck ${./test-rsync-send.sh}
      ${pkgs.bash}/bin/bash ${./test-rsync-send.sh} ${./rsync-send.sh}
    '';
  };
in
{
  home.packages = [ shellApplication ];
}
