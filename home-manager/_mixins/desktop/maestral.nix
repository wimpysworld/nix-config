{ pkgs, ... }:
{
  home.packages = with pkgs; [
    maestral-gui
  ];

  systemd.user.services = {
    maestral-gui = {
      Unit = {
        Description = "Maestral GUI";
      };
      Service = {
        ExecStart = "${pkgs.maestral-gui}/bin/maestral_qt";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
