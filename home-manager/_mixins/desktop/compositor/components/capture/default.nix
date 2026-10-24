{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  compositorQuery = import ../compositor-query/package.nix { inherit pkgs; };
  fuzzelCapture = pkgs.writeShellApplication {
    name = "fuzzel-capture";
    # Only the capture-specific tools. coreutils, util-linux (flock),
    # systemctl, pactl, xdg-open and wl-copy come from the system and the
    # desktop profile on every workstation.
    runtimeInputs = with pkgs; [
      compositorQuery
      fuzzel
      fyi
      grim
      jq
      lswt
      satty
      slurp
      swayosd
      wl-screenrec
      wlr-randr
    ];
    text = builtins.replaceStrings [ "@wlScreenrec@" ] [ (lib.getExe pkgs.wl-screenrec) ] (
      builtins.readFile ./fuzzel-capture.sh
    );
  };
in
lib.mkIf (host.is.linux && host.is.workstation) {
  home = {
    file = {
      "${config.xdg.configHome}/satty/config.toml".text = ''
        [general]
        fullscreen = false
        early-exit = false
        initial-tool = "pointer"
        copy-command = "${pkgs.wl-clipboard}/bin/wl-copy"
        annotation-size-factor = 2
        output-filename = "${config.home.homeDirectory}/Pictures/Screenshots/screenshot-%Y%m%d-%H%M%S.png"
        save-after-copy = false
        default-hide-toolbars = false
        primary-highlighter = "block"
        disable-notifications = false

        [font]
        family = "Work Sans"
        style = "Bold"
      '';
    };
    packages = with pkgs; [
      fuzzelCapture
      grim
      lswt
      satty
      slurp
      wlr-randr
    ];
  };

}
