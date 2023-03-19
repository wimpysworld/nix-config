{ config, desktop, inputs, lib, pkgs, stateVersion, username, ... }: {
  # Only import desktop configuragion if the host is desktop enabled
  imports = [
    ./_mixins/console
  ] ++ lib.optional (builtins.isString desktop) ./_mixins/desktop;

  home = {
    username = username;
    homeDirectory = "/home/" + username;
    stateVersion = stateVersion;
  };
}
