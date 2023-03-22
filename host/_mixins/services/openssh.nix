{ ... }: {
  services.openssh = {
    enable = true;
    #settings = {
      passwordAuthentication = false;
      permitRootLogin = "no";
    #};
  };
  programs.ssh.startAgent = true;
  networking.firewall.allowedTCPPorts = [ 22 ];
}
