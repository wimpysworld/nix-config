{ pkgs, ... }: {
  environment = {
    systemPackages = with pkgs; [
      evolutionWithPlugins
    ];
  };
  programs.evolution.enable = true;
  services.gnome.evolution-data-server.enable = true;
}
