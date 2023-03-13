{ pkgs, ... }: {
  hardware = {
    sane = {
      enable = true;
      extraBackends = with pkgs; [ hplipWithPlugin sane-airscan ];
    };
  };
}
