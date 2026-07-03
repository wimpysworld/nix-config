{ lib, pkgs, ... }:
{
  # The installer profile enables CIFS support, and cifs-utils drags the full
  # python3 interpreter (~126 MiB) into the closure. Installs never mount CIFS
  # shares, so drop it from the live media.
  boot.supportedFilesystems.cifs = lib.mkForce false;

  # The installer profile enables hardware.enableAllHardware, which switches on
  # every redistributable firmware package. Disable that (the profile assigns a
  # plain true, so mkForce is required) and hand-pick the firmware instead.
  # This drops sof-firmware, alsa-firmware, libreelec-dvb-firmware,
  # rtl8192su-firmware, ipw2200-firmware, and zd1211fw (~26 MiB of audio, DVB,
  # and obsolete Wi-Fi blobs the live installer never loads).
  hardware.enableRedistributableFirmware = lib.mkForce false;

  # The regulatory database defaults to the option disabled above, and Wi-Fi
  # on the live media still needs it.
  hardware.wirelessRegulatoryDatabase = true;

  # pkgs.linux-firmware resolves to the trimmed overlay version below.
  hardware.firmware = [
    pkgs.linux-firmware
    pkgs.rt5677-firmware
    pkgs.rtl8761b-firmware
  ];

  # Do not copy the nixpkgs source (~195 MiB) into the closure to serve the nix
  # path and flake registry; it would be a redundant third copy. The registry
  # pin from common/default.nix and the installer channel remain.
  nixpkgs.flake.setNixPath = false;
  nixpkgs.flake.setFlakeRegistry = false;

  nixpkgs.overlays = [
    (_final: super: {
      # Trim firmware classes no installer target can use (~460 MiB
      # uncompressed). GPU, Wi-Fi, Bluetooth, wired NIC, and CPU microcode
      # firmware all stay untouched.
      linux-firmware = super.linux-firmware.overrideAttrs (old: {
        postInstall =
          (old.postInstall or "")
          + ''
            # Datacenter and exotic NICs, and switch ASICs; no installer
            # target has these.
            rm -rf $out/lib/firmware/{mellanox,mrvl,netronome,dpaa2,qed,bnx2x,liquidio}
            rm -rf $out/lib/firmware/cxgb4*
            rm -rf $out/lib/firmware/phanfw.bin
            # Fibre Channel HBAs (Brocade bfa); the installer never boots
            # from a SAN.
            rm -rf $out/lib/firmware/{ctfw,cbfw,ct2fw}-*
            # DVB/TV tuners and capture codecs; useless on a live installer.
            # The dvb_* and sms1xxx-* globs catch the Siano DVB-T blobs that
            # use underscore and vendor prefixes instead of dvb-*.
            rm -rf $out/lib/firmware/dvb-*
            rm -rf $out/lib/firmware/dvb_*
            rm -rf $out/lib/firmware/sms1xxx-*
            rm -rf $out/lib/firmware/av7110
            rm -rf $out/lib/firmware/s5p-mfc*
            # Audio DSP firmware; the ISO has no audio stack.
            rm -rf $out/lib/firmware/{cirrus,ti,ti-connectivity}
            # Legacy serial, telephony, and pre-802.11n Wi-Fi hardware.
            rm -rf $out/lib/firmware/{ueagle-atm,moxa,libertas}
            # NVIDIA display firmware; the text install runs on the EFI
            # framebuffer.
            rm -rf $out/lib/firmware/nvidia
          ''
          + super.lib.optionalString super.stdenv.hostPlatform.isx86_64 ''
            # qcom firmware serves aarch64 Snapdragon machines that an x86_64
            # image can never boot, but a future ARM ISO must keep it.
            rm -rf $out/lib/firmware/qcom
          ''
          + ''
            # Delete symlinks left dangling by the removals so the firmware
            # compression step's link check passes.
            find "$out/lib/firmware" -xtype l -print -delete
          '';
      });
    })
  ];
}
