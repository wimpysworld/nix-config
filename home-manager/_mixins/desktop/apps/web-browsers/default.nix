{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" "martin.wimpress" ];
  inherit (pkgs.stdenv) isLinux isDarwin;
in
{
  home = {
    packages = with pkgs; lib.optionals (isDarwin) [
      wavebox
    ] ++ lib.optionals (isLinux) [
      mullvad-browser
    ];
  };

  programs = lib.mkIf (isDarwin && lib.elem username installFor) { 
    chromium = {
      extensions = [
        { id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa"; }  # 1Password
        { id = "hdokiejnpimakedhajhdlcegeplioahd"; }  # LastPass
        { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; }  # uBlock Origin
        { id = "kbfnbcaeplbcioakkpcpgfkobkghlhen"; }  # Grammarly
        { id = "mdjildafknihdffpkfmmpnpoiajfjnjd"; }  # Consent-O-Matic
        { id = "mnjggcdmjocbbbhaepdhchncahnbgone"; }  # SponsorBlock for YouTube
        { id = "gebbhagfogifgggkldgodflihgfeippi"; }  # Return YouTube Dislike
        { id = "fdpohaocaechififmbbbbbknoalclacl"; }  # GoFullPage
        { id = "clpapnmmlmecieknddelobgikompchkk"; }  # Disable Automatic Gain Control
        { id = "cdglnehniifkbagbbombnjghhcihifij"; }  # Kagi
        { id = "dpaefegpjhgeplnkomgbcmmlffkijbgp"; }  # Kagi Summariser
        { id = "mdkgfdijbhbcbajcdlebbodoppgnmhab"; }  # GoLinks
        { id = "glnpjglilkicbckjpbgcfkogebgllemb"; }  # Okta
        { id = "cfpdompphcacgpjfbonkdokgjhgabpij"; }  # Glean
        { id = "idefohglmnkliiadgfofeokcpjobdeik"; }  # Ramp
      ];
    };
  };
}
