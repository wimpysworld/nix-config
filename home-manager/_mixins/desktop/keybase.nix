{ pkgs, ... }:
{
  home.packages = with pkgs; [
    keybase-gui
  ];

  systemd.user.services = {
    keybase-gui = {
      Unit = {
        Description = "Keybase GUI";
      };
      Service = {
        ExecStart = "${pkgs.keybase-gui}/bin/keybase-gui";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
