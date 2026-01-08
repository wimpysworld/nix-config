{
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [
    "martin"
  ];
  inherit (pkgs.stdenv) isLinux isDarwin;
in
{
  home = {
    packages =
      with pkgs;
      lib.optionals isLinux [
        mullvad-browser
      ];
  };

  programs = lib.mkIf (isDarwin && lib.elem username installFor) {
    chromium = {
      extensions = [
        { id = "hdokiejnpimakedhajhdlcegeplioahd"; } # LastPass
        { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
        { id = "kbfnbcaeplbcioakkpcpgfkobkghlhen"; } # Grammarly
        { id = "mdjildafknihdffpkfmmpnpoiajfjnjd"; } # Consent-O-Matic
        { id = "mnjggcdmjocbbbhaepdhchncahnbgone"; } # SponsorBlock for YouTube
        { id = "gebbhagfogifgggkldgodflihgfeippi"; } # Return YouTube Dislike
        { id = "fdpohaocaechififmbbbbbknoalclacl"; } # GoFullPage
        { id = "clpapnmmlmecieknddelobgikompchkk"; } # Disable Automatic Gain Control
        { id = "cdglnehniifkbagbbombnjghhcihifij"; } # Kagi
        { id = "dpaefegpjhgeplnkomgbcmmlffkijbgp"; } # Kagi Summariser
      ];
    };
  };
}
