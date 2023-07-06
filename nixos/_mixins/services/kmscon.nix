{ pkgs, ... }: {
  services = {
    kmscon = {
      enable = true;
      hwRender = true;
      # Configure kmscon fonts via extraConfig so that we can use Nerd Fonts
      extraConfig = ''
        font-name=FiraCode Nerd Font Mono, SauceCodePro Nerd Font Mono
        font-size=14
      '';
      extraOptions = "--xkb-layout=uk";
    };
  };
}
