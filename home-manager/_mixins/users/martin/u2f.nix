{
  config,
  lib,
  pkgs,
  ...
}:
let
  username = config.noughty.user.name;
  inherit (pkgs.stdenv) isLinux;
  # Make with: pamu2fcfg -n
  u2f_28L = "TBfRqRfHADrZSgh4nOAwbCOgsbc0QTVwa0duBV3Qaz2ROuQ86QUR+70Hytzjicj88GhA0RRh2jNNe0ktKgzmXQ==,aUjvFdpwTbafll6K28EwSvLj7C+7XY/La+m3YXIeMTqRKu9+RarhGaOPQdXxfwwoa+ynjkZXtmVCkr5Nb+WPdQ==,es256,+presence";
  u2f_45L = "fitUdpvbJ6SMWMkojEDpOnUTdCXFt/qlQpZzXBpdQHzC/qPdKPBjo+HGmcLfIO+yGRsefmIb2jS4Gn3mDJ0CeA==,AKu1ho3I+PfNtB52egDBx/VAwrD5EMNl6zyTGgcvSHpp8AOWHwrbdfroIaoTGZNMZVWI4QvF8+HrTBv48lb7sA==,es256,+presence";
  u2f_bane = "1CGgpplq9YQv7JB9Au0Zusc6GWCuXatBpXeBgrFjEbCcnNd6Opi6yH4ybf/nbJzbBrC16/I/P259cMN1l4FNTw==,XEDLhzRweaSG6HQqXZJmkJlQQwsjMTXzgyjHOz5haNUKM2HjCn5eB/LOgN8oGdIUMlpD44TXF0OEgBa02KeD9w==,es256,+presence";
  u2f_keyring = "VyWPeIGWO3PA7ZeIxl1osBlEwv01mQUeYZfoed3qk+EdZThOAUIdIt+Ac+rTwix01x/B8QyErgJjjTKvMVDTbg==,BGGhoF38N4J0VNh05lRl3ho/4kAK+vEolNROoWadRG8hO6rtF7ROIMnTiojndKtXdzNfT6ML+ZJUWuIjiOZ01w==,es256,+presence";
  u2f_phasma = "U8Za14UahAnDSSwA6y2EJpDjIZP+0IliX9Ta//89oCvaNPGlVaxTCQY6VPShTNV41agGH+O+AuOfOcV6pIS9Wg==,2o6OE9jB4E62FGcCmAPDXaY4FyT5uSNBVW9LydetbJFgZem9GZtJ1tnXt2FJm/sHgmg8BBqIY+QIf/r+5oFXMw==,es256,+presence";
  u2f_vader = "G4S+zVnfPIpcnShvEuLYazwAS8XhX8DRyZZBX2OdV3K+7RVbr4UG+TqmmT3kEgC0XgTpKpN2cM/t4CpFDUE9Ig==,xxXHLkGtoMUAEbyu7/TMxmPGjuqISDVT1ldSy7qoWppWzgNlyvZZiu5bST7Llf3sHLDsT/agFbqzuf4HcVJZcw==,es256,+presence";
in
lib.mkIf isLinux {
  home.packages = with pkgs; [
    yubikey-manager
    pam_u2f
    pamtester
  ];

  xdg.configFile."Yubico/u2f_keys".text = ''
    ${username}:${u2f_28L}:${u2f_45L}:${u2f_bane}:${u2f_keyring}:${u2f_phasma}:${u2f_vader}
  '';
}
