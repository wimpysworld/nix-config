{ pkgs, ... }:
{
  # https://localsend.org/
  home.packages = with pkgs; [
    localsend
  ];

  systemd.user.services = {
    localsend = {
      Unit = {
        Description = "LocalSend";
      };
      Service = {
        ExecStart = "${pkgs.localsend}/bin/localsend";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
