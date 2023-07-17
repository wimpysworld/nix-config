{ lib, ... }: {
  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = lib.mkDefault "no";
      };
    };
    sshguard = {
      enable = true;
      whitelist = [
        "192.168.2.0/24"
        "192.168.192.0/24"
        "62.31.16.154"
        "80.209.186.67"
      ];
    };
  };
  programs.ssh.startAgent = true;
  networking.firewall.allowedTCPPorts = [ 22 ];
}
