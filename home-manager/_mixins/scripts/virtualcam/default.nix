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
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      coreutils
      # The script copies the stream with -c:v copy, so the headless build's
      # Video4Linux2 input and output are enough.
      ffmpeg-headless
      fyi
      kmod
      procps
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
lib.mkIf (host.is.linux && noughtyLib.hostHasTag "pci-hdmi-capture") {
  home.packages = with pkgs; [ shellApplication ];
}
