{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Don't open the firewall for SSH on laptops; Tailscale will handle it.
  openSSHFirewall =
    if (!config.noughty.host.is.iso && config.noughty.host.is.laptop) then false else true;
in
{
  environment = lib.mkIf (!config.noughty.host.is.iso) {
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
      enable = !config.noughty.host.is.iso;
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
