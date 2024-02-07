{ pkgs, ... }: {
  programs.firefox = {
    enable = true;
    languagePacks = [ "en-GB" ];
    package = pkgs.firefox;
  };
}
