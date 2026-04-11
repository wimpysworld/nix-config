{
  config,
  inputs,
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
    kernelParams = [
      "iommu=pt"
      "video=DP-1:2560x2880@60"
      "video=DP-4:2560x2880@60"
    ];
    swraid = {
      enable = true;
      mdadmConf = "MAILADDR=${username}@wimpys.world";
    };
  };

  boot.extraModprobeConfig = ''
    # Disable runtime power management to prevent GPU clock gating between inference calls.
    options amdgpu runpm=0
    # Expand GTT pool to ~120 GB (4 KiB pages: 120 * 1024^3 / 4096 = 31457280).
    options ttm pages_limit=31457280
  '';

  # Force GPU to high performance clock on device add.
  # Without this the GPU idles at 600 MHz, halving inference throughput.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="drm", KERNEL=="card[0-9]*", DRIVERS=="amdgpu", \
      ATTR{device/power_dpm_force_performance_level}="high"
  '';

  hardware.mwProCapture.enable = true;

  systemd.tmpfiles.rules = [
    "d /home/${username}/.cache 0755 ${username} users -"
    "d /home/${username}/.lima 0755 ${username} users -"
    "d /home/${username}/.local 0755 ${username} users -"
    "d /home/${username}/.local/share 0755 ${username} users -"
    "d /home/${username}/.local/share/containers 0700 ${username} users -"
    "d /home/${username}/Quickemu 0755 ${username} users -"
    "d /home/${username}/Development 0755 ${username} users -"
    "d /home/${username}/Volatile 0755 ${username} users -"
  ];

}
