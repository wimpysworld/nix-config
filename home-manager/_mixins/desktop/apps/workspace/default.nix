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
  slackWavebox = (
    inputs.xdg-override.lib.wrapPackage {
      nameMatch = [
        {
          case = "^https?://";
          command = "wavebox";
        }
      ];
    } pkgs.slack
  );
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
lib.mkIf (lib.elem username installFor) {
  home = {
    packages =
      with pkgs;
      lib.optionals isDarwin [
        wavebox
      ]
      ++ lib.optionals isLinux [
        slackWavebox
        waveboxXdgOpen # Integrate Wavebox with Slack, GitHub, Auth, etc.
      ];
  };
}
