{ pkgs, ... }: {
  home = {
    packages = with pkgs; [
      neofetch
    ];
    file = {
      ".config/neofetch/config.conf".text = builtins.readFile ./neofetch.conf;
    };
  };
}
