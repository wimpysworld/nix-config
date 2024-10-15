{
  isInstall,
  isLaptop,
  lib,
  pkgs,
  ...
}:
{
  environment = lib.mkIf isInstall { systemPackages = with pkgs; [ ssh-to-age ]; };
  programs = {
    mosh.enable = isInstall;
    ssh.startAgent = true;
  };
  services = {
    openssh = {
      enable = true;
      # Don't open the firewall on for SSH on laptops; Tailscale will handle it.
      openFirewall = !isLaptop;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = lib.mkDefault "no";
      };
    };
    sshguard = {
      enable = true;
      whitelist = [
        "192.168.2.0/24"
        "62.31.16.154"
        "80.209.186.64/28"
      ];
    };
  };
}
