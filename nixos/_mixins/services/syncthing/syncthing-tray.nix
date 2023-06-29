{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [ 
    syncthingtray-minimal
  ];
}
