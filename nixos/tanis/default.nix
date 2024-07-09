{ inputs, lib, pkgs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-z13-gen1
    ./disks.nix
    ../_mixins/services/filesync.nix
    ../_mixins/services/caddy
    ../_mixins/services/homepage
    ../_mixins/services/tailscale
  ];

  boot = {
    initrd = {
      availableKernelModules = [
        "nvme"
        "sd_mod"
        "thunderbolt"
        "uas"
        "xhci_pci"
      ];
      systemd.enable = true;
    };
    kernelModules = [ "amdgpu" "kvm-amd" ];
    # Wake from suspend regression in Linux 6.7 and 6.8
    # Use pkgs.linuxPackages_6_6 until it's fixed
    # - https://bugzilla.kernel.org/show_bug.cgi?id=217239 (ath11k firmware bug)
    # - https://gitlab.freedesktop.org/drm/amd/-/issues/3153 (amdgpu bug - bisect)
    # - https://gitlab.freedesktop.org/drm/amd/-/issues/3132 (amdgpu bug)
    #   - # - https://gitlab.freedesktop.org/drm/amd/-/issues/3132#note_2271275 (summary)

    kernelPackages = lib.mkForce pkgs.linuxPackages_6_6;
  };
}
