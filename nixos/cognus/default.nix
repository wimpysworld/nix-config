{ lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/openstack-config.nix")
  ];

  boot = {
    initrd.kernelModules = [
      "xen-blkfront"
      "xen-tpmfront"
      "xen-kbdfront"
      "xen-fbfront"
      "xen-netfront"
      "xen-pcifront"
      "xen-scsifront"
    ];

    # Show debug kernel messages in the OpenStack console during boot.
    consoleLogLevel = lib.mkForce 7;
    kernel.sysctl."kernel.printk" = "4 4 1 7";
    kernelParams = lib.mkForce [ "console=ttyS0" ];

    # GandiCloud exposes the root disk through Xen as /dev/xvda.
    loader = {
      efi.canTouchEfiVariables = lib.mkForce false;
      grub = {
        enable = true;
        device = lib.mkForce "/dev/xvda";
      };
      systemd-boot.enable = lib.mkForce false;
    };
  };

  # Dedicated volume for the GoToSocial SQLite database, attached through Xen as
  # /dev/xvdb. Mount by label, because OpenStack device names can shift on
  # reattach, and grow the filesystem automatically when the volume is enlarged.
  fileSystems."/var/lib/gotosocial" = {
    device = "/dev/disk/by-label/gts-db";
    fsType = "ext4";
    options = [
      "defaults"
      "x-systemd.growfs"
    ];
  };

  networking.tempAddresses = "disabled";

  systemd.services = {
    "serial-getty@ttyS0" = {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Restart = "always";
    };

    "serial-getty@tty1".enable = lib.mkForce false;

    "getty@tty1" = {
      enable = lib.mkForce true;
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Restart = "always";
    };
  };
}
