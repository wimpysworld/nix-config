{ inputs, platform, ... }: {
  environment = {
    systemPackages = with inputs; [
      antsy-alien-attack-pico.packages.${platform}.default
    ];
  };
}
