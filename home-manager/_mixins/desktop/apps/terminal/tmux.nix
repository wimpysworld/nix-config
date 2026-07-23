{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:

lib.mkIf
  (noughtyLib.isHost [
    "skrye"
    "zannah"
  ])
  {
    catppuccin.tmux = {
      enable = config.programs.tmux.enable;
      extraConfig = ''
        set -g @catppuccin_status_modules_right "application session user host date_time"
      '';
    };

    programs.tmux = {
      enable = true;
      package = pkgs.tmux.override {
        withSixel = true;
      };
      clock24 = true;
      historyLimit = 65536;
      keyMode = "emacs";
      mouse = true;
      sensibleOnTop = true;
      terminal = "tmux-256color";
      extraConfig = ''
        set -s input-buffer-size 16777216
      '';
    };
  }
