{
  isInstall,
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
      openFirewall = true;
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
        "80.209.186.67"
      ];
    };
  };
}
