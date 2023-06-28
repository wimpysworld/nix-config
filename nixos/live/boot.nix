{ config, lib, pkgs, ... }: {
  boot = {
    consoleLogLevel = 3;
    initrd = {
      verbose = false;
    };
  };
}
