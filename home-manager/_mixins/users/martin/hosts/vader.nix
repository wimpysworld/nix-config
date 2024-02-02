{ config, lib, ... }:
with lib.hm.gvariant;
{
  imports = [
    ../../../desktop/deckmaster-xl.nix
  ];

  # Disable unused audio devices
  # pactl list
  # - alsa_card.pci-0000_30_00.1:          HDA NVidia T1000
  # - alsa_card.pci-0000_33_00.1:          Navi 21/23 HDMI/DP Audio Controller
  # - alsa_card.pci-0000_26_00.0:          Magewell (00-00 Pro Capture Quad HDMI)
  # - alsa_card.pci-0000_27_00.0:          Magewell (00-01 Pro Capture Quad HDMI)
  # - alsa_card.pci-0000_28_00.0:          Magewell (00-02 Pro Capture Quad HDMI) (keep, device capture is used by OBS Studio)
  # - alsa_card.pci-0000_29_00.0:          Magewell (00-03 Pro Capture Quad HDMI)
  home.file.".config/wireplumber/main.lua.d/51-disable-cards.lua".text = ''
    rule = {
      matches = {
        {
          { "device.name", "equals", "alsa_card.pci-0000_30_00.1" },
          { "device.name", "equals", "alsa_card.pci-0000_33_00.1" },
          { "device.name", "equals", "alsa_card.pci-0000_26_00.0" },
          { "device.name", "equals", "alsa_card.pci-0000_27_00.0" },
          { "device.name", "equals", "alsa_card.pci-0000_29_00.0" },
        },
      },
      apply_properties = {
        ["device.disabled"] = true,
      },
    }
    table.insert(alsa_monitor.rules,rule)
  '';

  dconf.settings = {
    "org/gnome/desktop/background" = {
      picture-options = "zoom";
      picture-uri = "file://${config.home.homeDirectory}/Pictures/Determinate/DeterminateColorway-2560x1440.png";
    };
  };
}
