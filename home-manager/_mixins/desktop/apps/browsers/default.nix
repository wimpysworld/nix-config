{
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin;
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
in
{
  # Install browser extension for macOS and nix-darwin doesn't support it yet
  programs = {
    brave = {
      enable = isDarwin;
      extensions =
        if (noughtyLib.isUser [ "martin" ]) then basicExtensions ++ advancedExtensions else basicExtensions;
    };
  };
}
