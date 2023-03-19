{ config, desktop, inputs, lib, pkgs, stateVersion, username, ... }: {
  # Only import desktop configuration if the host is desktop enabled
  # Only import user specific configuration if they have bespoke settings
  imports = [
    ./_mixins/console
  ]
  ++ lib.optional (builtins.isString desktop) ./_mixins/desktop
  ++ lib.optional (builtins.isPath (./. + "/_mixins/users/${username}")) ./_mixins/users/${username};

  home = {
    username = username;
    homeDirectory = "/home/" + username;
    stateVersion = stateVersion;
  };
}
