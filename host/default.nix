{ desktop, hostname, lib, modulesPath, stateVersion, username, ...}: {
  # Import host specific boot and hardware configurations.
  # Only include desktop components if one is supplied.
  # - https://nixos.wiki/wiki/Nix_Language:_Tips_%26_Tricks#Coercing_a_relative_path_with_interpolated_variables_to_an_absolute_path_.28for_imports.29
  imports = [
    (./. + "/${hostname}/boot.nix")
    (./. + "/${hostname}/hardware.nix")
    (modulesPath + "/installer/scan/not-detected.nix")
    ./_mixins/base
    ./_mixins/boxes
    ./_mixins/users/root
    ./_mixins/users/${username}
  ] ++ lib.optional (builtins.isString desktop) ./_mixins/desktop;

  system.stateVersion = stateVersion;
}
