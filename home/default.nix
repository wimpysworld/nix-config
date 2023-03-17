{ config, desktop, inputs, lib, pkgs, username, ... }: {
  # Only import desktop configuragion if the host is desktop enabled
  imports = [
    ./_mixins/console
  ] ++ lib.optional (builtins.isString desktop) ./_mixins/desktop;

  home = {
    username = username;
    homeDirectory = "/home/" + username;
    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    stateVersion = "22.11";
  };
}
