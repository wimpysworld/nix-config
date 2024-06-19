{ desktop, hostname, lib, pkgs, username, ... }:
let
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
in
{
  programs = {
    chromium = {
      extensions = [
        "kbfnbcaeplbcioakkpcpgfkobkghlhen" # Grammarly
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
        "mdjildafknihdffpkfmmpnpoiajfjnjd" # Consent-O-Matic
        "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock for YouTube
        "gebbhagfogifgggkldgodflihgfeippi" # Return YouTube Dislike
        "fdpohaocaechififmbbbbbknoalclacl" # GoFullPage
        "clpapnmmlmecieknddelobgikompchkk" # Disable Automatic Gain Control
        "cdglnehniifkbagbbombnjghhcihifij" # Kagi
        "bkkmolkhemgaeaeggcmfbghljjjoofoh" # Catppuccin Mocha
      ];
      # - https://help.kagi.com/kagi/getting-started/setting-default.html
      extraOpts = {
        # Default search provider; Kagi
        "DefaultSearchProviderAlternateURLs" = [
          "https://kagi.com/search?q={searchTerms}"
        ];
        "DefaultSearchProviderImageURL" = "https://assets.kagi.com/v2/apple-touch-icon.png";
        "DefaultSearchProviderKeyword" = "kagi";
        "DefaultSearchProviderName" = "Kagi";
        "DefaultSearchProviderSearchURL" = "https://kagi.com/search?q={searchTerms}";
        "DefaultSearchProviderSuggestURL" = "https://kagi.com/api/autosuggest?q={searchTerms}";
        "HomePageLocation" = "https://${hostname}.drongo-gamma.ts.net";
        "NewTabPageLocation" = "https://${hostname}.drongo-gamma.ts.net";
      };
    };
  };
}
