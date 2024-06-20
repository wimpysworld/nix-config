{ lib, pkgs, ... }:
{
  services = {
    gpg-agent.pinentryPackage = lib.mkForce pkgs.pinentry-gnome3;
    # https://nixos.wiki/wiki/Bluetooth#Using_Bluetooth_headsets_with_PulseAudio
    mpris-proxy.enable = true;
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
