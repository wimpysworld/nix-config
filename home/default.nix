{ config, desktop, inputs, lib, outputs, pkgs, username, ... }: {
  # Only import desktop configuragion if the host is desktop enabled
  imports = [
    ./_mixins/console
  ] ++ lib.optional (desktop != null) ./_mixins/desktop;

  home = {
    username = username;
    homeDirectory = "/home/" + username;
    stateVersion = "22.11";
  };
}
