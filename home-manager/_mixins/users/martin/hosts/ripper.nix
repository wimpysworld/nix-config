{ lib, ... }:
with lib.hm.gvariant;
{
  imports = [
    ../../../services/keybase.nix
    ../../../services/mpris-proxy.nix
    ../../../services/syncthing.nix
    ../../../desktop/deckmaster-xl.nix
    ../../../desktop/sakura.nix
    ../../../desktop/vorta.nix
  ];

  # Disable unused audio devices
  # - alsa_card.usb-Generic_USB_Audio-00:  Motherboard (Realtek-ALC1220-VB-Desktop)
  # - alsa_card.pci-0000_03_00.1:          NVIDIA (HDA NVidia)
  # - alsa_card.pci-0000_23_00.1:          AMD (Navi 21/23 HDMI/DP Audio Controller)
  # - alsa_card.pci-0000_4e_00.0:          Magewell (00-01 Pro Capture Quad HDMI)
  # - alsa_card.pci-0000_4f_00.0:          Magewell (00-02 Pro Capture Quad HDMI)
  # - alsa_card.pci-0000_50_00.0:          Magewell (00-03 Pro Capture Quad HDMI)
  home = {
    file.".config/wireplumber/main.lua.d/51-disable-cards.lua".text = ''
      rule = {
        matches = {
          {
            { "device.name", "equals", "alsa_card.usb-Generic_USB_Audio-00" },
            { "device.name", "equals", "alsa_card.pci-0000_03_00.1" },
            { "device.name", "equals", "alsa_card.pci-0000_23_00.1" },
            { "device.name", "equals", "alsa_card.pci-0000_4e_00.0" },
            { "device.name", "equals", "alsa_card.pci-0000_4f_00.0" },
            { "device.name", "equals", "alsa_card.pci-0000_50_00.0" },
          },
        },
        apply_properties = {
          ["device.disabled"] = true,
        },
      }
      table.insert(alsa_monitor.rules,rule)
    '';
  };

  dconf.settings = {
    "org/gnome/desktop/background" = {
      picture-options = "zoom";
      picture-uri = "file:///home/martin/Pictures/Determinate/DeterminateColorway-2560x1440.png";
    };
  };
}
