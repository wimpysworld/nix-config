# Origins of the Herdr Mobile Relay phone app. Caddy on each host serves the
# app over the tailnet, and Home Manager uses these URLs for setup links. Each
# host has one base URL, so moving an app changes one value.
{ tailNet }:
rec {
  appUrls = {
    skrye = "https://skrye.${tailNet}:8443";
    zannah = "https://zannah.${tailNet}:8443";
  };
  # The Herdr `setup-link` action uses this app on every host.
  defaultApp = "skrye";
  defaultAppUrl = appUrls.${defaultApp};
}
