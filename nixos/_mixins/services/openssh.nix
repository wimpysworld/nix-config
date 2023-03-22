{ lib, ... }: {
  services.openssh = {
    enable = true;
    #settings = {
      passwordAuthentication = false;
      permitRootLogin = lib.mkDefault "no";
    #};
  };
  programs.ssh.startAgent = true;
  networking.firewall.allowedTCPPorts = [ 22 ];
}
