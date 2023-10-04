{ inputs, platform, ... }: {
  environment = {
    shellAliases = {
      l    = "${inputs.eza.packages.${platform}.default}/bin/eza -lah";
      la   = "${inputs.eza.packages.${platform}.default}/bin/eza -a";
      ll   = "${inputs.eza.packages.${platform}.default}/bin/eza -l";
      lla  = "${inputs.eza.packages.${platform}.default}/bin/eza -la";
      ls   = "${inputs.eza.packages.${platform}.default}/bin/eza";
      tree = "${inputs.eza.packages.${platform}.default}/bin/eza --tree";
    };
    systemPackages = with inputs; [
      antsy-alien-attack-pico.packages.${platform}.default
      fh.packages.${platform}.default
      eza.packages.${platform}.default
    ];
  };
}
