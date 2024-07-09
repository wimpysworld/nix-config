{ config, desktop, hostname, lib, pkgs, username, ... }:
let
  isWorkstation = if (desktop != null) then true else false;
  unmanagedInterfaces = [ ]
    ++ lib.optionals config.services.tailscale.enable [ "tailscale0" ]
    ++ lib.optionals config.virtualisation.lxd.enable [ "lxd0" ];

  # Trust the lxd bridge interface, if lxd is enabled
  # Trust the tailscale interface, if tailscale is enabled
  trustedInterfaces = [ ]
    ++ lib.optionals config.services.tailscale.enable [ "tailscale0" ]
    ++ lib.optionals config.virtualisation.lxd.enable [ "lxd0" ];

  # Firewall configuration variable for syncthing
  syncthing = {
    hosts = [
      "phasma"
      "sidious"
      "tanis"
      "vader"
      "revan"
    ];
    tcpPorts = [ 22000 ];
    udpPorts = [ 22000 21027 ];
  };
  # Define DNS settings for specific users
  # - https://cleanbrowsing.org/filters/
  defaultDns = [ "1.1.1.1" "1.0.0.1" ];
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
in
{
  imports = lib.optional (builtins.pathExists (./. + "/${hostname}.nix")) ./${hostname}.nix;

  networking = {
    extraHosts = ''
      192.168.2.1     router
      192.168.2.6     vader-wifi
      192.168.2.7     vader-lan
      192.168.2.11    printer
      192.168.2.20    keylight-left key-left Elgato_Key_Light_Air_DAD4
      192.168.2.21    keylight-right key-right Elgato_Key_Light_Air_EEE9
      192.168.2.23    moodlamp
      192.168.2.30    chimeraos-lan
      192.168.2.31    chimeraos-wifi chimeraos
      192.168.2.58    vonage Vonage-HT801
      192.168.2.184   lametric LaMetric-LM2144
      192.168.2.250   hue-bridge
    '';
    firewall = {
      enable = true;
      allowedTCPPorts = [ ]
        ++ lib.optionals (builtins.elem hostname syncthing.hosts) syncthing.tcpPorts;
      allowedUDPPorts = [ ]
        ++ lib.optionals (builtins.elem hostname syncthing.hosts) syncthing.udpPorts;
      trustedInterfaces = trustedInterfaces;
    };
    hostName = hostname;
    # Use resolved for DNS resolution; tailscale requires it
    networkmanager = lib.mkIf (isWorkstation) {
      dns = "systemd-resolved";
      enable = true;
      # Conditionally set Public DNS based on username, defaulting if user not matched
      insertNameservers = if builtins.hasAttr username userDnsSettings then
                            userDnsSettings.${username}
                          else
                            defaultDns;
      unmanaged = unmanagedInterfaces;
      wifi.backend = "iwd";
    };
    useDHCP = lib.mkDefault true;
  };
  # Use resolved for DNS resolution; tailscale requires it
  services.resolved.enable = true;

  # Belt and braces disable WiFi power saving
  systemd.services.disable-wifi-powersave = lib.mkIf (config.networking.networkmanager.wifi.powersave) {
    wantedBy = ["multi-user.target"];
    path = [ pkgs.iw ];
    script = ''
      iw dev wlan0 set power_save off
    '';
  };
  # Workaround https://github.com/NixOS/nixpkgs/issues/180175
  systemd.services.NetworkManager-wait-online.enable = false;
}
