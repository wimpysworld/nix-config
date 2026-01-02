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
  waveboxXdgOpen = inputs.xdg-override.lib.proxyPkg {
    inherit pkgs;
    nameMatch = [
      {
        case = "^https?://accounts.google.com";
        command = "wavebox";
      }
      {
        case = "^https?://github.com/login/device";
        command = "wavebox";
      }
      {
        case = "^https?://auth.chainguard.dev/activate";
        command = "wavebox";
      }
      {
        case = "^https?://issuer.enforce.dev";
        command = "wavebox";
      }
    ];
  };
in
{
  home = {
    packages =
      with pkgs;
      lib.optionals isDarwin [
        wavebox
      ]
      ++ lib.optionals isLinux [
        mullvad-browser
      ]
      ++ lib.optionals pkgs.stdenv.isLinux [
        waveboxXdgOpen # Integrate Wavebox with Slack, GitHub, Auth, etc.
      ];
  };

  programs = lib.mkIf (isDarwin && lib.elem username installFor) {
    chromium = {
      extensions = [
        { id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa"; } # 1Password
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
        { id = "mdkgfdijbhbcbajcdlebbodoppgnmhab"; } # GoLinks
        { id = "glnpjglilkicbckjpbgcfkogebgllemb"; } # Okta
        { id = "cfpdompphcacgpjfbonkdokgjhgabpij"; } # Glean
        { id = "idefohglmnkliiadgfofeokcpjobdeik"; } # Ramp
      ];
    };
  };
}
