{ inputs, platform, ... }: {
  environment = {
    shellAliases = {
        l    = "eza -lah";
        la   = "eza -a";
        ll   = "eza -l";
        lla  = "eza -la";
        ls   = "eza";
        tree = "eza --tree";
      };
    systemPackages = with inputs; [
      fh.packages.${platform}.default
      eza.packages.${platform}.default
    ];
  };
}
