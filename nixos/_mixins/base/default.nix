{ desktop, hostname, inputs, lib, pkgs, ... }:
let
  # Do not enable the base system on .iso live images
  isInstall = builtins.substring 0 4 hostname != "iso-";
in
lib.mkIf (isInstall) {
  environment.systemPackages = with pkgs; [
    nvme-cli
    smartmontools
  ] ++ lib.optionals (desktop != null) [
    gsmartcontrol
  ];

  programs = {
    nix-index-database.comma.enable = true;
    nix-ld.enable = true;
  };

  services = {
    fwupd.enable = true;
    kmscon = {
      enable = true;
      hwRender = true;
      fonts = [{
        name = "FiraCode Nerd Font Mono";
        package = pkgs.nerdfonts.override { fonts = [ "FiraCode" ]; };
      }];
      extraConfig = ''
        font-size=14
        xkb-layout=gb
      '';
    };
    smartd.enable = true;
  };

  system = {
    activationScripts.diff = {
      supportsDryActivation = true;
      text = ''
        if [ -e /run/current-system/boot.json ] && ! ${pkgs.gnugrep}/bin/grep -q "LABEL=nixos-minimal" /run/current-system/boot.json; then
          ${pkgs.nvd}/bin/nvd --nix-bin-dir=${pkgs.unstable.nix}/bin diff /run/current-system "$systemConfig"
        fi
      '';
    };
    nixos.label = "-";
  };
}
