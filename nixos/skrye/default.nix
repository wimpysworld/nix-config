{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  username = config.noughty.user.name;
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
    ./disks.nix
    ./disks-snapshot.nix
  ];

  boot = {
    initrd.availableKernelModules = [
      "thunderbolt"
    ];
    initrd.systemd.enable = true;
    kernelModules = [
      "amdgpu"
      "kvm-amd"
    ];
    # The SSL USB interface handles all audio. Block the HD Audio driver so
    # that the Radeon HDMI and DisplayPort audio and the Ryzen analogue
    # audio never appear as sound cards.
    blacklistedKernelModules = [ "snd_hda_intel" ];
    swraid = {
      enable = true;
      mdadmConf = "MAILADDR=${username}@wimpys.world";
    };
  };

  boot.extraModprobeConfig = ''
    # Expand GTT pool to ~120 GB (4 KiB pages: 120 * 1024^3 / 4096 = 31457280).
    options ttm pages_limit=31457280
  '';

  hardware.mwProCapture.enable = true;

  systemd.tmpfiles.rules = [
    "d /home/${username}/.cache 0755 ${username} users -"
    "d /home/${username}/.local 0755 ${username} users -"
    "d /home/${username}/.local/share 0755 ${username} users -"
    "d /home/${username}/.local/share/containers 0700 ${username} users -"
    "d /home/${username}/Quickemu 0755 ${username} users -"
    "d /home/${username}/Development 0755 ${username} users -"
    "d /home/${username}/Volatile 0755 ${username} users -"
  ];

}
