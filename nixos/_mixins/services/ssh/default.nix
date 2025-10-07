{
  isInstall,
  isLaptop,
  lib,
  pkgs,
  ...
}:
let
  # Don't open the firewall for SSH on laptops; Tailscale will handle it.
  openSSHFirewall = if (isInstall && isLaptop) then false else true;
in
{
  environment = lib.mkIf isInstall { systemPackages = with pkgs; [ ssh-to-age ]; };
  programs = {
    ssh.startAgent = true;
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
      enable = isInstall;
      whitelist = [
        "10.10.10.0/24"
        "62.31.16.153/29"
        "80.209.186.64/28"
      ];
    };
  };
}
