{
  pkgs,
  fuzzel,
  configFile,
  tailNet,
}:
assert pkgs.lib.assertMsg (pkgs.lib.versionAtLeast fuzzel.version "1.14")
  "fuzzel-connections requires Fuzzel >= 1.14 for hidden search fields";
let
  inherit (pkgs) lib;
  systems = builtins.fromTOML (builtins.readFile ../../../../../../lib/registry-systems.toml);

  # The HTTPS port that the `roamgate-serve` user service in
  # `home-manager/_mixins/terminal/herdr.nix` publishes with Tailscale Serve.
  roamgatePort = "10000";
  # The noVNC path that the Caddy virtual host in
  # `nixos/_mixins/server/caddy/default.nix` serves on ReFrame hosts.
  reframePath = "/novnc";

  # Tailscale runs on NixOS workstations and servers, as
  # `nixos/_mixins/network/tailscale/default.nix` sets. This repeats the
  # registry resolution in `lib/flake-builders.nix`: a host is a workstation
  # when it has a desktop, and a computer gets a desktop unless it is an ISO.
  hasTailscale =
    entry:
    let
      tags = entry.tags or [ ];
      homeOnly = lib.any (tag: lib.elem tag tags) [
        "wsl"
        "steamdeck"
        "generic-linux"
      ];
      workstation = entry ? desktop || (entry.kind == "computer" && !(lib.elem "iso" tags));
    in
    lib.hasSuffix "-linux" entry.platform && !homeOnly && (workstation || entry.kind == "server");

  # Roamgate and ReFrame run on the tailnet hosts that have their registry tag.
  taggedHosts =
    tag:
    lib.attrNames (
      lib.filterAttrs (
        _: entry: builtins.isAttrs entry && hasTailscale entry && lib.elem tag (entry.tags or [ ])
      ) systems
    );

  mkEntries =
    {
      tag,
      service,
      glyph,
      mkUrl,
    }:
    map (host: {
      inherit host service;
      label = "${glyph} ${service} (${host})";
      url = mkUrl "${host}.${tailNet}";
    }) (taggedHosts tag);

  # Weave is published through a Cloudflare Tunnel, so its public hostname is
  # in `nixos/_mixins/server/weave/README.md` and not in a Nix value.
  weave = {
    host = "revan";
    service = "Weave";
    label = "󰠮 Weave";
    url = "https://notes.wimpys.world";
  };

  services =
    lib.sort (a: b: if a.service == b.service then a.host < b.host else a.service < b.service)
      (
        mkEntries {
          tag = "reframe";
          service = "ReFrame";
          glyph = "󰢹";
          mkUrl = fqdn: "https://${fqdn}${reframePath}";
        }
        ++ mkEntries {
          tag = "roamgate";
          service = "Roamgate";
          glyph = "󰳆";
          mkUrl = fqdn: "https://${fqdn}:${roamgatePort}/";
        }
      );

  entries = map (entry: {
    inherit (entry) label url;
    keywords = "${entry.service} ${entry.host}";
  }) ([ weave ] ++ services);

  validUrl = url: lib.hasPrefix "https://" url || lib.hasPrefix "http://" url;

  pickerConfig = pkgs.writeText "fuzzel-connections.ini" ''
    [main]
    include=${configFile}

    [key-bindings]
    execute-input=none
  '';
  catalogue = pkgs.writeText "fuzzel-connections.json" (builtins.toJSON entries);
in
assert lib.all (
  entry:
  lib.assertMsg (validUrl entry.url) "fuzzel-connections: ${entry.label} has a URL that is not http or https: ${entry.url}"
) entries;
pkgs.writeShellApplication {
  name = "fuzzel-connections";
  runtimeInputs = with pkgs; [
    fuzzel
    jq
    util-linux
    xdg-utils
  ];
  runtimeEnv = {
    FUZZEL_CONNECTIONS = catalogue;
    FUZZEL_CONNECTIONS_CONFIG = pickerConfig;
  };
  text = builtins.readFile ./fuzzel-connections.sh;
  passthru = { inherit entries; };
}
