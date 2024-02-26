{ desktop, lib, pkgs, username, ... }:
let
  # Define DNS settings for specific users
  # - https://cleanbrowsing.org/filters/
  userDnsSettings = {
    # Security Filter:
    # - Blocks access to phishing, spam, malware and malicious domains.
    martin = [ "185.228.168.9" "185.228.169.9" ];

    # Adult Filter:
    # - Blocks access to all adult, pornographic and explicit sites.
    # - It does not block proxy or VPNs, nor mixed-content sites.
    # - Sites like Reddit are allowed.
    # - Google and Bing are set to the Safe Mode.
    # - Malicious and Phishing domains are blocked.
    louise = [ "185.228.168.10" "185.228.169.11" ];

    # Family Filter:
    # - Blocks access to all adult, pornographic and explicit sites.
    # - It also blocks proxy and VPN domains that are used to bypass the filters.
    # - Mixed content sites (like Reddit) are also blocked.
    # - Google, Bing and Youtube are set to the Safe Mode.
    # - Malicious and Phishing domains are blocked.
    agatha = [ "185.228.168.168" "185.228.169.168" ];
  };
  # Default DNS settings if user not listed above
  defaultDns = [ "1.1.1.1" "1.0.0.1" ];
in
{
  environment.systemPackages = with pkgs; lib.mkIf (desktop == "mate") [
    networkmanagerapplet
  ];

  networking = {
    networkmanager = {
      enable = true;
      # Conditionally set Public DNS based on username, defaulting if user not matched
      insertNameservers = if builtins.hasAttr username userDnsSettings then
                             userDnsSettings.${username}
                           else
                             defaultDns;
      wifi = {
        backend = "iwd";
        powersave = false;
      };
    };
    wireless.iwd.package = pkgs.iwd;
  };

  programs = lib.mkIf (desktop == "mate") {
    nm-applet.enable = true;
  };
}
