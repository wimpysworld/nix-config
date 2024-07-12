{
  config,
  hostname,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  unmanagedInterfaces =
    lib.optionals config.services.tailscale.enable [ "tailscale0" ]
    ++ lib.optionals config.virtualisation.lxd.enable [ "lxd0" ];

  # Trust the lxd bridge interface, if lxd is enabled
  # Trust the tailscale interface, if tailscale is enabled
  trustedInterfaces =
    lib.optionals config.services.tailscale.enable [ "tailscale0" ]
    ++ lib.optionals config.virtualisation.lxd.enable [ "lxd0" ];

  # Per-host firewall configuration; mostly for Syncthing which is configured via Home Manager
  allowedTCPPorts = {
    phasma = [ 22000 ];
    sidious = [ 22000 ];
    tanis = [ 22000 ];
    vader = [ 22000 ];
    revan = [ 22000 ];
  };
  allowedUDPPorts = {
    phasma = [
      22000
      21027
    ];
    sidious = [
      22000
      21027
    ];
    tanis = [
      22000
      21027
    ];
    vader = [
      22000
      21027
    ];
    revan = [
      22000
      21027
    ];
  };

  # Define DNS settings for specific users
  # - https://mullvad.net/en/help/dns-over-https-and-dns-over-tls
  fallbackDns = [ "194.242.2.2#dns.mullvad.net" ];
  userDns = {
    # adblock.dns.mullvad.net; ads, trackers
    martin = [ "194.242.2.3#adblock.dns.mullvad.net" ];

    # base.dns.mullvad.net; ads, trackers, malware
    louise = [ "194.242.2.4#base.dns.mullvad.net" ];

    # family.dns.mullvad.net; ads, trackers, malware, adult, gambling
    agatha = [ "194.242.2.6#family.dns.mullvad.net" ];
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
      allowedTCPPorts =
        lib.optionals (builtins.hasAttr hostname allowedTCPPorts)
          allowedTCPPorts.${hostname};
      allowedUDPPorts =
        lib.optionals (builtins.hasAttr hostname allowedUDPPorts)
          allowedUDPPorts.${hostname};
      inherit trustedInterfaces;
    };
    hostName = hostname;
    nameservers = if builtins.hasAttr username userDns then userDns.${username} else fallbackDns;
    networkmanager = lib.mkIf isWorkstation {
      # Use resolved for DNS resolution; tailscale MagicDNS requires it
      dns = "systemd-resolved";
      enable = true;
      unmanaged = unmanagedInterfaces;
      wifi.backend = "iwd";
    };
    useDHCP = lib.mkDefault true;
  };
  services = {
    avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        addresses = true;
        enable = true;
        workstation = isWorkstation;
      };
    };
    # Use resolved for DNS resolution; tailscale MagicDNS requires it
    resolved = {
      enable = true;
      domains = [ "~." ];
      dnsovertls = "true";
      dnssec = "false";
      inherit fallbackDns;
    };
  };

  # Belt and braces disable WiFi power saving
  systemd.services.disable-wifi-powersave =
    lib.mkIf
      (
        lib.isBool config.networking.networkmanager.wifi.powersave
        && config.networking.networkmanager.wifi.powersave
      )
      {
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.iw ];
        script = ''
          iw dev wlan0 set power_save off
        '';
      };
  # Workaround https://github.com/NixOS/nixpkgs/issues/180175
  systemd.services.NetworkManager-wait-online.enable = false;

  users.users.${username}.extraGroups = lib.optionals config.networking.networkmanager.enable [
    "networkmanager"
  ];
}
