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
      "video=DP-1:2560x2880@60"
      "video=DP-4:2560x2880@60"
    ];
    swraid = {
      enable = true;
      mdadmConf = "MAILADDR=${username}@wimpys.world";
    };
  };

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
