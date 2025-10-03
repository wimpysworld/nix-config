{
  config,
  lib,
  pkgs,
  ...
}:
let
  shellAliases = {
    htop = "${pkgs.bottom}/bin/btm --basic --tree --hide_table_gap --dot_marker";
    top = "${pkgs.bottom}/bin/btm --basic --tree --hide_table_gap --dot_marker";
  };
in
{
  catppuccin.bottom.enable = config.programs.bottom.enable;

  programs = {
    bottom = {
      enable = true;
      settings = {
        disk_filter = {
          is_list_ignored = true;
          list = [ "/dev/loop" ];
          regex = true;
          case_sensitive = false;
          whole_word = false;
        };
        flags = {
          dot_marker = false;
          enable_gpu_memory = true;
          group_processes = true;
          hide_table_gap = true;
          mem_as_value = true;
          tree = true;
        };
      };
    };
    bash.shellAliases = lib.mkIf config.programs.bottom.enable shellAliases;
    fish.shellAliases = lib.mkIf config.programs.bottom.enable shellAliases;
    zsh.shellAliases = lib.mkIf config.programs.bottom.enable shellAliases;
  };

  xdg = {
    desktopEntries = {
      bottom = {
        name = "bottom";
        noDisplay = true;
      };
    };
  };
}
