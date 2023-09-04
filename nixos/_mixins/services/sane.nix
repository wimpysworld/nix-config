{ desktop, lib, pkgs, ... }: {
  environment.systemPackages = with pkgs; [ ] ++ lib.optionals (desktop != null) [
    gnome.simple-scan
  ];

  hardware = {
    sane = {
      enable = true;
      #extraBackends = with pkgs; [ hplipWithPlugin sane-airscan ];
      extraBackends = with pkgs; [ sane-airscan ];
    };
  };
}
