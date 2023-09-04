{ pkgs, ... }:
{
  networking = {
    networkmanager = {
      enable = true;
      # Use AdGuard Public DNS with ad/tracker blocking
      #  - https://adguard-dns.io/en/public-dns.html
      insertNameservers = [ "94.140.14.14" "94.140.15.15" ];
      wifi = {
        backend = "iwd";
        powersave = false;
      };
    };
    wireless.iwd.package = pkgs.unstable.iwd;
  };
  # Workaround https://github.com/NixOS/nixpkgs/issues/180175
  systemd.services.NetworkManager-wait-online.enable = false;
}
