{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;
  isWorkHost = noughtyLib.hostHasTag "cg";
in
lib.mkIf (host.is.workstation && !isWorkHost && noughtyLib.isUser [ "martin" ]) {
  programs = {
    chromium = {
      # - https://help.kagi.com/kagi/getting-started/setting-default.html
      extraOpts = {
        # Default search provider; Kagi
        "DefaultSearchProviderAlternateURLs" = [ "https://kagi.com/search?q={searchTerms}" ];
        "DefaultSearchProviderImageURL" = "https://assets.kagi.com/v2/apple-touch-icon.png";
        "DefaultSearchProviderKeyword" = "kagi";
        "DefaultSearchProviderName" = "Kagi";
        "DefaultSearchProviderSearchURL" = "https://kagi.com/search?q={searchTerms}";
        "DefaultSearchProviderSuggestURL" = "https://kagi.com/api/autosuggest?q={searchTerms}";
        "HomePageLocation" = "https://kagi.com";
        "NewTabPageLocation" = "https://kagi.com";
      };
    };
  };
}
