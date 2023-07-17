_: {
  # Provides users with access to all Elgato StreamDecks.
  # https://github.com/muesli/deckmaster
  # https://gitlab.gnome.org/World/boatswain/-/blob/main/README.md#udev-rules
  services.udev.extraRules = ''
    # Deckmaster needs write access to uinput to simulate keypresses.
    # Users wanting to use Deckmaster should be added to the input group.
    KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput", GROUP="input", MODE="0660"

    # Elgato Stream Deck Mini
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0063", TAG+="uaccess", SYMLINK+="streamdeck-mini"

    # Elgato Stream Deck Mini (v2)
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0090", TAG+="uaccess", SYMLINK+="streamdeck-mini"

    # Elgato Stream Deck Original
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0060", TAG+="uaccess", SYMLINK+="streamdeck"

    # Elgato Stream Deck Original (v2)
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006d", TAG+="uaccess", SYMLINK+="streamdeck"

    # Elgato Stream Deck MK.2
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0080", TAG+="uaccess", SYMLINK+="streamdeck"

    # Elgato Stream Deck XL
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", TAG+="uaccess", SYMLINK+="streamdeck-xl"

    # Elgato Stream Deck XL (v2)
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="008f", TAG+="uaccess", SYMLINK+="streamdeck-xl"

    # Elgato Stream Deck Pedal
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0086", TAG+="uaccess", SYMLINK+="streamdeck-pedal"
  '';
}
