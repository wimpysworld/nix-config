{
  config,
  hostname,
  isLaptop,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  useDoT = if isLaptop then "opportunistic" else "true";
  unmanagedInterfaces =
    lib.optionals config.services.tailscale.enable [ "tailscale0" ]
    ++ lib.optionals config.virtualisation.lxd.enable [ "lxd0" ]
    ++ lib.optionals config.virtualisation.incus.enable [ "incusbr0" ];

  # Trust the lxd bridge interface, if lxd is enabled
  # Trust the incus bridge interface, if incus is enabled
  # Trust the tailscale interface, if tailscale is enabled
  trustedInterfaces =
    lib.optionals config.services.tailscale.enable [ "tailscale0" ]
    ++ lib.optionals config.virtualisation.lxd.enable [ "lxd0" ]
    ++ lib.optionals config.virtualisation.incus.enable [ "incusbr0" ];

  # Per-host firewall configuration; mostly for Syncthing which is configured via Home Manager
  allowedTCPPorts = {
    phasma = [ 22000 ];
    vader = [ 22000 ];
    revan = [ 22000 ];
  };
  allowedUDPPorts = {
    phasma = [
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
  mullvadDns = [
    "194.242.2.2#dns.mullvad.net"
    "2a07:e340::2#dns.mullvad.net"
  ];
  # adblock.dns.mullvad.net; ads, trackers
  mullvadAdblockDns = [
    "194.242.2.3#adblock.dns.mullvad.net"
    "2a07:e340::3#adblock.dns.mullvad.net"
  ];
  # base.dns.mullvad.net; ads, trackers, malware
  mullvadBlockmalwareDns = [
    "194.242.2.4#base.dns.mullvad.net"
    "2a07:e340::4#base.dns.mullvad.net"
  ];
  # family.dns.mullvad.net; ads, trackers, malware, adult, gambling
  mullvadFamilyDns = [
    "194.242.2.6#family.dns.mullvad.net"
    "2a07:e340::6#family.dns.mullvad.net"
  ];
  # https://adguard-dns.io/en/public-dns.html
  adguardDns = [
    "94.140.14.140#unfiltered.adguard-dns.com"
    "94.140.14.141#unfiltered.adguard-dns.com"
    "2a10:50c0::1:ff#unfiltered.adguard-dns.com"
    "2a10:50c0::2:ff#unfiltered.adguard-dns.com"
  ];
  adguardBlockmalwareDns = [
    "94.140.14.14#dns.adguard-dns.com"
    "94.140.15.15#dns.adguard-dns.com"
    "2a10:50c0::ad1:ff#dns.adguard-dns.com"
    "2a10:50c0::ad2:ff#dns.adguard-dns.com"
  ];
  adguardFamilyDns = [
    "94.140.14.15#family.adguard-dns.com"
    "94.140.15.16#family.adguard-dns.com"
    "2a10:50c0::bad1:ff#family.adguard-dns.com"
    "2a10:50c0::bad2:ff#family.adguard-dns.com"
  ];

  fallbackDns = if useDoT == "true" then mullvadDns else adguardDns;
  userDns = {
    martin = if useDoT == "true" then mullvadBlockmalwareDns else adguardBlockmalwareDns;
    louise = if useDoT == "true" then mullvadBlockmalwareDns else adguardBlockmalwareDns;
    agatha = if useDoT == "true" then mullvadFamilyDns else adguardFamilyDns;
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
    # https://wiki.nixos.org/wiki/Incus
    nftables.enable = lib.mkIf config.virtualisation.incus.enable true;
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
      dnsovertls = useDoT;
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
  systemd.services.NetworkManager-wait-online.enable = lib.mkIf config.networking.networkmanager.enable false;

  users.users.${username}.extraGroups = lib.optionals config.networking.networkmanager.enable [
    "networkmanager"
  ];
}
