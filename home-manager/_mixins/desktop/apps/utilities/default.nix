{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  isLanMouseHost = noughtyLib.hostHasTag "lan-mouse";
  lanMousePeers = {
    ravi = {
      name = "zannah";
      position = "bottom";
      fingerprint = "e5:da:7e:0a:dc:66:bc:b6:c4:f9:94:46:e5:d7:38:8a:55:5a:87:bd:fb:6c:66:ef:0b:8e:03:b8:34:61:4a:db";
    };
    zannah = {
      name = "ravi";
      position = "top";
      fingerprint = "46:ee:b9:ff:7f:96:02:88:a1:7e:aa:6d:44:a6:2e:69:a8:81:2a:83:c9:10:85:49:ce:c8:8a:a4:f3:06:c0:68";
    };
  };
  lanMousePeer = lanMousePeers.${host.name} or null;
  compositor = lib.attrByPath [
    host.desktop
  ] null (import ../../../../../lib/wayland-compositors.nix).compositors;
in
lib.mkIf (noughtyLib.isUser [ "martin" ] && host.is.workstation && host.is.linux) {
  assertions = [
    {
      assertion = !isLanMouseHost || lanMousePeer != null;
      message = "Lan-mouse hosts require an explicit peer and trusted certificate fingerprint.";
    }
  ];

  home.packages = with pkgs; [
    cpu-x
    gnome-firmware
    usbimager
    vaults
  ];

  programs.lan-mouse = lib.mkIf isLanMouseHost {
    enable = true;
    settings = lib.mkIf (lanMousePeer != null) {
      port = 4242;
      cert_path = config.sops.secrets.lan_mouse_identity.path;
      authorized_fingerprints = lib.optionalAttrs (host.name == "ravi") {
        ${lanMousePeer.fingerprint} = lanMousePeer.name;
      };
      clients = lib.optional (host.name == "zannah") {
        hostname = "${lanMousePeer.name}-lanmouse";
        inherit (lanMousePeer) position;
        activate_on_startup = true;
      };
    };
  };

  sops.secrets.lan_mouse_identity = lib.mkIf (isLanMouseHost && lanMousePeer != null) {
    sopsFile = ../../../../../secrets/host-${host.name}-lan-mouse.json;
    format = "binary";
    mode = "0400";
  };

  systemd.user.services.lan-mouse =
    lib.mkIf (isLanMouseHost && lanMousePeer != null && compositor != null)
      {
        Unit = {
          After = [ "sops-nix.service" ];
          Requires = [ "sops-nix.service" ];
          PartOf = [ compositor.sessionTarget ];
        };
        Service.ExecStartPre = "${pkgs.coreutils}/bin/test -r ${config.sops.secrets.lan_mouse_identity.path}";
        Install.WantedBy = lib.mkForce [ compositor.sessionTarget ];
      };
}
