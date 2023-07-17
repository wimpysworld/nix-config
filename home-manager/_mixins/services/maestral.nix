{ desktop, lib, pkgs, ... }: {
  imports = [ ] ++ lib.optionals (desktop != null) [
    ../desktop/maestral.nix
  ];
  
  home.packages = with pkgs; [
    maestral
  ];
  
  systemd.user.services = {
    maestral = {
      Unit = {
        Description = "Maestral";
      };
      Service = {
        ExecStart = "${pkgs.maestral}/bin/maestral start";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
