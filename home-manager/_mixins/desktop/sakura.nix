{ config, pkgs, ... }: {
  home = {
    file = {
      "${config.xdg.configHome}/sakura/sakura.conf".text = builtins.readFile ./sakura.conf;
    };
    packages = with pkgs; [
      sakura
    ];
  };
}
