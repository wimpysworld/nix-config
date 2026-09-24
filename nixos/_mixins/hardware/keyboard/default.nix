# HID input device support for workstations. Consolidates USB keyboard
# udev access rules and keyd event remapping in one module.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.noughty.host.is.workstation {
  environment.systemPackages = [ inputs.nix-packages.packages.${pkgs.system}.wonkey ];

  services = {
    # Provides users with access to VIA
    # https://get.vial.today/manual/linux-udev.html
    udev.extraRules = ''
      #0x320f 0x5055 Crush80
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="320f", ATTRS{idProduct}=="5055", TAG+="uaccess", TAG+="udev-acl", GROUP="input", MODE="0660", SYMLINK+="crush80"
      #0x320f 0x5088 Crush80-2.4G
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="320f", ATTRS{idProduct}=="5088", TAG+="uaccess", TAG+="udev-acl", GROUP="input", MODE="0660", SYMLINK+="crush80-24g"
      #0x359b 0x0004 Drop CSTM80
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="359b", ATTRS{idProduct}=="0004", TAG+="uaccess", TAG+="udev-acl", GROUP="input", MODE="0660", SYMLINK+="CSTM80"
      #0x36b0 0x300e Evoworks EVO80
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="36b0", ATTRS{idProduct}=="300e", TAG+="uaccess", TAG+="udev-acl", GROUP="input", MODE="0660", SYMLINK+="evo80"
      #0xaf88 0x6688 XFKey One Key Max
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="af88", ATTRS{idProduct}=="6688", TAG+="uaccess", TAG+="udev-acl", GROUP="input", MODE="0660", SYMLINK+="xfkey"
    '';

    keyd = {
      enable = true;
      keyboards = {
        # Kensington SlimBlade Pro Trackball, scoped by VID:PID.
        slimbladeProTrackball = {
          ids = [
            "m:047d:80d6"
            "m:047d:80d7"
          ];
          settings.main = {
            leftmouse = "rightmouse";
            rightmouse = "leftmouse";
            mouse1 = "middlemouse";
          };
        };
      };
    };
  };

  users.users.${config.noughty.user.name}.extraGroups = [ "input" ];
}
