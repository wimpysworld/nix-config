{
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
  basicExtensions = [
    { id = "hdokiejnpimakedhajhdlcegeplioahd"; } # LastPass
  ];
  advancedExtensions = [
    { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
    { id = "kbfnbcaeplbcioakkpcpgfkobkghlhen"; } # Grammarly
    { id = "mdjildafknihdffpkfmmpnpoiajfjnjd"; } # Consent-O-Matic
    { id = "mnjggcdmjocbbbhaepdhchncahnbgone"; } # SponsorBlock for YouTube
    { id = "gebbhagfogifgggkldgodflihgfeippi"; } # Return YouTube Dislike
    { id = "fdpohaocaechififmbbbbbknoalclacl"; } # GoFullPage
    { id = "clpapnmmlmecieknddelobgikompchkk"; } # Disable Automatic Gain Control
    { id = "cdglnehniifkbagbbombnjghhcihifij"; } # Kagi
    { id = "dpaefegpjhgeplnkomgbcmmlffkijbgp"; } # Kagi Summariser
    #{ id = "bkkmolkhemgaeaeggcmfbghljjjoofoh"; } # Catppuccin Mocha
    { id = "lnjaiaapbakfhlbjenjkhffcdpoompki"; } # Catppuccin Web file explorer icons
    { id = "clngdbkpkpeebahjckkjfobafhncgmne"; } # Stylus
    { id = "mdpfkohgfpidohkakdbpmnngaocglmhl"; } # Disable Ctrl + Scroll Zoom
  ];
  installFor = [
    "martin"
  ];
in
{
  programs = {
    brave = {
      enable = lib.elem username installFor;
      extensions =
        if (lib.elem username installFor) then basicExtensions ++ advancedExtensions else basicExtensions;
    };
    chromium = {
      enable = isLinux;
      extensions =
        if (lib.elem username installFor) then basicExtensions ++ advancedExtensions else basicExtensions;
    };
  };
}
