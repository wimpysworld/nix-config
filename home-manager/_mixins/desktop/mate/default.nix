{ lib, pkgs, ... }:
{
  home.file = {
    ".local/share/plank/themes/Catppuccin-mocha/dock.theme".text = builtins.readFile ../../configs/plank-catppuccin-mocha.theme;
  };

  services = {
    gpg-agent.pinentryPackage = lib.mkForce pkgs.pinentry-gnome3;
  };

  systemd.user.services = {
    # https://github.com/tom-james-watson/emote
    emote = {
      Unit = {
        Description = "Emote";
      };
      Service = {
        ExecStart = "${pkgs.emote}/bin/emote";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
