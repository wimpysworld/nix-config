{ config, pkgs, ...}:
let
  ifExists = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  imports = [
    ./packages.nix
  ];

  users.users.nix = {
    description = "Default user account"
    extraGroups = [
        "audio"
        "networkmanager"
        "video"
        "wheel"
      ]
      ++ ifExists [
        "docker"
      ];
    # mkpasswd -m sha-512
    hashedPassword = "$6$CP19bGL3hB0FbzR4$YZ.cklhLhqW35N1UKHYvBeYrNO6UFBDY7nWErvAU/heB5/pGGEIRj0RjKBA6RRxUhlIm/mRih2Z3aHhh3UVsg.";
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAywaYwPN4LVbPqkc+kUc7ZVazPBDy4LCAud5iGJdr7g9CwLYoudNjXt/98Oam5lK7ai6QPItK6ECj5+33x/iFpWb3Urr9SqMc/tH5dU1b9N/9yWRhE2WnfcvuI0ms6AXma8QGp1pj/DoLryPVQgXvQlglHaDIL1qdRWFqXUO2u30X5tWtDdOoR02UyAtYBttou4K0rG7LF9rRaoLYP9iCBLxkMJbCIznPD/pIYa6Fl8V8/OVsxYiFy7l5U0RZ7gkzJv8iNz+GG8vw2NX4oIJfAR4oIk3INUvYrKvI2NSMSw5sry+z818fD1hK+soYLQ4VZ4hHRHcf4WV4EeVa5ARxdw== Martin Wimpress"
    ];
    packages = [ pkgs.home-manager ];
    shell = pkgs.fish;
  };
}
