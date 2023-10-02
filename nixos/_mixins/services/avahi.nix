{ desktop, ...}: {
  services = {
    avahi = {
      enable = true;
      nssmdns = true;
      openFirewall = true;
      publish = {
        addresses = true;
      	enable = true;
      	workstation = if (builtins.isString desktop) then true else false;
      };
    };
  };
}
