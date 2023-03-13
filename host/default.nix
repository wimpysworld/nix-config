{ desktop, hostid, hostname, pkgs, lib, username, ...}: {
  # Import host specific boot and hardware configurations.
  # Only include desktop components if one is supplied.
  # - https://nixos.wiki/wiki/Nix_Language:_Tips_%26_Tricks#Coercing_a_relative_path_with_interpolated_variables_to_an_absolute_path_.28for_imports.29
  imports = [
    (./. + "/${hostname}/boot.nix")
    (./. + "/${hostname}/hardware.nix")
    ./_mixins/base
    ./_mixins/boxes
    ./_mixins/users/root
    ./_mixins/users/${username}
  ] ++ lib.optional (desktop != null) ./_mixins/desktop;

  # Use passed in hostid and hostname to configure basic networking
  networking = {
    hostName = hostname;
    hostId = hostid;
    useDHCP = lib.mkDefault true;
    firewall = {
      enable = true;
    };
  };
  system.stateVersion = "22.11";
}
