{
  lib,
  isInstall,
  pkgs,
  ...
}:
{
  environment = {
    systemPackages =
      with pkgs;
      lib.optionals isInstall [
        evolutionWithPlugins
      ];
  };

  programs = {
    dconf.profiles.user.databases = [
      {
        settings = with lib.gvariant; {
          "org/gnome/evolution/mail" = {
            monospace-font = "FiraCode Nerd Font Mono Medium 13";
            search-gravatar-for-photo = true;
            show-sender-photo = true;
            variable-width-font = "Work Sans 12";
          };

          #"org/gnome/evolution/plugin/external-editor" = {
          #  command = "pluma";
          #};
        };
      }
    ];
    evolution.enable = isInstall;
  };

  # Enable services to round out the desktop
  services = {
    gnome.evolution-data-server.enable = lib.mkForce isInstall;
  };
}
