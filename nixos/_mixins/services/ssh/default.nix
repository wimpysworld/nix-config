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
        PermitRootLogin = lib.mkDefault "prohibit-password";
      };
    };
    sshguard = {
      enable = true;
      whitelist = [
        "10.10.10.0/24"
        "62.31.16.153/29"
        "80.209.186.64/28"
      ];
    };
  };
}
