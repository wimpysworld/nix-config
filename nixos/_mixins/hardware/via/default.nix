{
  config,
  lib,
  ...
}:
let
  host = config.noughty.host;
  username = config.noughty.user.name;
in
lib.mkIf (!host.is.iso) {
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
    '';
  };
  users.users.${username} = {
    extraGroups = [ "input" ];
  };
}
