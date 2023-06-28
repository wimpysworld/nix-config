{ lib, pkgs, ... }: {
  programs = {
    firefox = {
      enable = lib.mkDefault true;
      languagePacks = ["en-GB"];
      package = pkgs.unstable.firefox;
    };
  };
}
