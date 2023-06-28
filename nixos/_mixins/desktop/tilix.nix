{ pkgs, ... }: {
  environment = {
    systemPackages = with pkgs; [
      tilix                       # Tiling terminal emulator
    ];
  };
}
