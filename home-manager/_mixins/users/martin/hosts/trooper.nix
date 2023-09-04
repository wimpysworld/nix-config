{ config, lib, ... }:
with lib.hm.gvariant;
{
  imports = [
    ../../../desktop/deckmaster-xl.nix
    ../../../desktop/vorta.nix
  ];

  # Disable unused audio devices
  # - alsa_card.pci-0000_0a_00.1: NVIDIA (HDA NVidia)
  home = {
    file.".config/wireplumber/main.lua.d/51-disable-cards.lua".text = ''
      rule = {
        matches = {
          {
            { "device.name", "equals", "alsa_card.pci-0000_0a_00.1" },
            { "device.name", "equals", "alsa_card.usb-AVerMedia_Technologies__Inc._Live_Streamer_CAM_513_5203711200146-00" },
            { "device.name", "equals", "alsa_card.usb-Elgato_Cam_Link_4K_000592F643000-03" },
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
      picture-uri = "file://${config.home.homeDirectory}/Pictures/Determinate/DeterminateColorway-3440x1440.png";
    };
  };
}
