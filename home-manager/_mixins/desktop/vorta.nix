{ pkgs, ... }:
{
  home.packages = with pkgs; [
    vorta
  ];

  systemd.user.services = {
    vorta = {
      Unit = {
        Description = "Vorta";
      };
      Service = {
        ExecStart = "${pkgs.vorta}/bin/vorta --daemonise";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
