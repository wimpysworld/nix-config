{
  config,
  lib,
  pkgs,
  ...
}:
let
  host = config.noughty.host;
  # Don't open the firewall for SSH on laptops; Tailscale will handle it.
  openSSHFirewall = if (!host.is.iso && host.is.laptop) then false else true;
in
{
  environment = lib.mkIf (!host.is.iso) {
    systemPackages = with pkgs; [ ssh-to-age ];
  };
  programs = {
    # Only start the SSH agent if no other keyring is managing keys
    ssh.startAgent = !config.services.gnome.gnome-keyring.enable;
  };
  services = {
    openssh = {
      enable = true;
      openFirewall = openSSHFirewall;
      settings = {
        PasswordAuthentication = false;
      };
    };
    sshguard = {
      enable = !host.is.iso;
      whitelist = [
        "10.10.10.0/24"
        "10.10.30.0/24"
        "10.10.40.0/24"
        "10.10.50.0/24"
        "62.31.16.153/29"
        "80.209.186.64/28"
      ];
    };
  };
}
