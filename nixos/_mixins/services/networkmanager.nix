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
    wireless.iwd.package = pkgs.iwd;
  };
}
