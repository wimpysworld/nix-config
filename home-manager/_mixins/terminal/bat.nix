{
  config,
  lib,
  pkgs,
  ...
}:
let
  shellAliases = {
    brg = "${pkgs.bat-extras.batgrep}/bin/batgrep";
    cat = "${pkgs.bat}/bin/bat --paging=never";
    less = "${pkgs.bat}/bin/bat";
    more = "${pkgs.bat}/bin/bat";
  };
in
{
  catppuccin.bat.enable = config.programs.bat.enable;

  home = {
    sessionVariables = lib.mkIf config.programs.bat.enable {
      MANPAGER = "sh -c 'col --no-backspaces --spaces | ${pkgs.bat}/bin/bat --language man'";
      MANROFFOPT = "-c";
      PAGER = "${pkgs.bat}/bin/bat";
    };
  };

  programs = {
    bat = {
      enable = true;
      extraPackages = with pkgs.bat-extras; [
        batgrep
        batwatch
        prettybat
      ];
      config = {
        style = "plain";
      };
    };
    bash.shellAliases = lib.mkIf config.programs.bat.enable shellAliases;
    fish.shellAliases = lib.mkIf config.programs.bat.enable shellAliases;
    zsh.shellAliases = lib.mkIf config.programs.bat.enable shellAliases;
  };
}
