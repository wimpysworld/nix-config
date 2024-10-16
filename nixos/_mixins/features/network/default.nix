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
  mullvadBaseDns = [
    "194.242.2.4#base.dns.mullvad.net"
    "2a07:e340::4#base.dns.mullvad.net"
  ];
  # family.dns.mullvad.net; ads, trackers, malware, adult, gambling
  mullvadFamilyDns = [
    "194.242.2.6#family.dns.mullvad.net"
    "2a07:e340::6#family.dns.mullvad.net"
  ];
  # https://developers.cloudflare.com/1.1.1.1/ip-addresses/
  cloudflareDns = [
    "1.1.1.1"
    "1.0.0.1"
    "2606:4700:4700::1111"
    "2606:4700:4700::1001"
  ];
  cloudflareBlockmalwareDns = [
    "1.1.1.2"
    "1.0.0.2"
    "2606:4700:4700::1112"
    "2606:4700:4700::1002"
  ];
  cloudflareFamilyDns = [
    "1.1.1.3"
    "1.0.0.3"
    "2606:4700:4700::1113"
    "2606:4700:4700::1003"
  ];

  fallbackDns = if useDoT != "true" then mullvadDns else cloudflareDns;
  userDns = {
    martin = if useDoT != "true" then mullvadAdblockDns else cloudflareBlockmalwareDns;
    louise = if useDoT != "true" then mullvadBaseDns else cloudflareBlockmalwareDns;
    agatha = if useDoT != "true" then mullvadFamilyDns else cloudflareFamilyDns;
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
