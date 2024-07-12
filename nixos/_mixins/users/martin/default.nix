{
  inputs,
  isWorkstation,
  lib,
  platform,
  username,
  ...
}:
{
  environment = {
    systemPackages =
      with inputs;
      lib.optionals (isWorkstation) [ antsy-alien-attack-pico.packages.${platform}.default ];
  };

  users.users.martin = {
    description = "Martin Wimpress";
    # mkpasswd -m sha-512
    hashedPassword = "$6$UXNQ20Feu82wCFK9$dnJTeSqoECw1CGMSUdxKREtraO.Nllv3/fW9N3m7lPHYxFKA/Cf8YqYGDmiWNfaKeyx2DKdURo0rPYBrSZRL./";
  };

  systemd.tmpfiles.rules = [ "d /mnt/snapshot/${username} 0755 ${username} users" ];
}
