{ pkgs, ... }:
{
  # https://github.com/tom-james-watson/emote
  home.packages = with pkgs.unstable; [
    emote
  ];

  systemd.user.services = {
    emote = {
      Unit = {
        Description = "Emote";
      };
      Service = {
        ExecStart = "${pkgs.unstable.emote}/bin/emote";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
