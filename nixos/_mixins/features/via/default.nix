{ username, ... }:
{
  services = {
    # Provides users with access to VIA
    # https://get.vial.today/manual/linux-udev.html
    udev.extraRules = ''
      #0x320f 0x5055
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="320f", ATTRS{idProduct}=="5055", TAG+="uaccess", TAG+="udev-acl", GROUP="input", MODE="0660", SYMLINK+="crush80"
      #0x359b 0x0004
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="359b", ATTRS{idProduct}=="0004", TAG+="uaccess", TAG+="udev-acl", GROUP="input", MODE="0660", SYMLINK+="CSTM80"
    '';
  };
  users.users.${username} = {
    extraGroups = [ "input" ];
  };
}
