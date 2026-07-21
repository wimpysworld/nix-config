{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf
  (
    noughtyLib.isHost [
      "skrye"
      "zannah"
    ]
    && host.is.linux
  )
  {
    catppuccin.foot.enable = config.programs.foot.enable;

    programs.foot = {
      enable = true;
      package = pkgs.foot;
      settings = {
        main = {
          font = "FiraCode Nerd Font Mono:size=16";
          pad = "2x2";
          term = "foot";
        };
        cursor = {
          blink = "yes";
          blink-rate = 750;
          style = "block";
        };
        mouse.hide-when-typing = "yes";
        scrollback.lines = 65536;
      };
    };
  }
