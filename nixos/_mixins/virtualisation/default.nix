{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  username = config.noughty.user.name;
  rootlessMode = false;

  # Introspect the root filesystem type from disko configuration
  # Docker storage driver recommendations:
  # - btrfs: use "btrfs" driver for native snapshot support
  # - xfs: use "overlay2" (default, good performance)
  # - ext4: use "overlay2" (default, most common)
  # - zfs: use "zfs" driver for native dataset support
  #
  # This function recursively searches through the disko configuration to find
  # the filesystem type used for the root (/) mountpoint.
  getRootFsType =
    let
      # Extract filesystem type from disko devices
      findRootFs =
        disk:
        if disk ? content then
          if disk.content ? type then
            if
              disk.content.type == "filesystem" && disk.content ? mountpoint && disk.content.mountpoint == "/"
            then
              disk.content.format or null
            else if disk.content.type == "gpt" && disk.content ? partitions then
              lib.findFirst (x: x != null) null (
                lib.mapAttrsToList (_: findRootFs) disk.content.partitions
              )
            else if disk.content.type == "luks" && disk.content ? content then
              findRootFs disk.content
            else if disk.content.type == "btrfs" && disk.content ? subvolumes then
              lib.findFirst (x: x != null) null (
                lib.mapAttrsToList (
                  _: subvol: if subvol ? mountpoint && subvol.mountpoint == "/" then "btrfs" else null
                ) disk.content.subvolumes
              )
            else
              null
          else
            null
        else
          null;

      diskoDisks = config.disko.devices.disk or { };
      rootFsType = lib.findFirst (x: x != null) null (lib.mapAttrsToList (_: findRootFs) diskoDisks);
    in
    rootFsType;

  # Map filesystem type to optimal Docker storage driver
  storageDriver =
    let
      fsType = getRootFsType;
    in
    if fsType == "btrfs" then
      "btrfs"
    else if fsType == "zfs" then
      "zfs"
    else
      "overlay2"; # Default for xfs, ext4, and others
in
lib.mkIf (noughtyLib.isUser [ "martin" ] && host.is.workstation) {
  environment = {
    # https://wiki.nixos.org/wiki/Docker
    systemPackages =
      with pkgs;
      [
        docker-color-output
        docker-compose
        docker-init
        docker-sbom
        lazydocker
      ]
      ++ lib.optional rootlessMode fuse-overlayfs;
  };

  hardware.nvidia-container-toolkit.enable = host.gpu.hasNvidia;

  users.users.${username} = {
    extraGroups = lib.optional config.virtualisation.docker.enable "docker";
  };

  virtualisation = {
    containers.enable = true;
    docker = {
      enable = true;
      daemon = {
        settings = {
          features.cdi = host.gpu.hasNvidia;
        };
      };
      rootless = lib.mkIf rootlessMode {
        enable = rootlessMode;
        setSocketVariable = rootlessMode;
      };
      inherit storageDriver;
    };
    oci-containers = lib.mkIf config.virtualisation.docker.enable {
      backend = "docker";
    };
    spiceUSBRedirection.enable = true;
  };
}
