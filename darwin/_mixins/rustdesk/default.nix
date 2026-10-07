{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  appDirectory = "/Applications/RustDesk.app/Contents/MacOS";
  configure = pkgs.writeShellApplication {
    name = "configure-rustdesk";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.python3
    ];
    text = builtins.readFile ./configure-rustdesk.sh;
  };
  passwordFile = config.sops.secrets.rustdesk-password.path;
  agentName = "com.carriez.RustDesk_server.plist";
  agentSource = config.environment.launchAgents.${agentName}.source;
in
{
  imports = [ inputs.sops-nix.darwinModules.sops ];

  config = lib.mkIf config.noughty.host.is.workstation {
    homebrew.casks = [ "rustdesk" ];

    sops = {
      age.keyFile = lib.mkDefault "/Users/${config.noughty.user.name}/.config/sops/age/keys.txt";
      secrets.rustdesk-password = {
        sopsFile = ../../../secrets/rustdesk.yaml;
        key = "password";
        owner = "root";
        group = "wheel";
        mode = "0400";
      };
    };

    launchd = {
      daemons = {
        rustdesk-service = {
          script = ''
            ${configure}/bin/configure-rustdesk --check-app || exit 1
            exec ${appDirectory}/service
          '';
          serviceConfig = {
            Label = "com.carriez.RustDesk_service";
            WorkingDirectory = appDirectory;
            RunAtLoad = true;
            KeepAlive = true;
            ThrottleInterval = 1;
            StandardErrorPath = "/var/log/rustdesk_service.err";
            StandardOutPath = "/var/log/rustdesk_service.out";
          };
        };
        rustdesk-configure.serviceConfig = {
          ProgramArguments = [
            "${configure}/bin/configure-rustdesk"
            passwordFile
          ];
          RunAtLoad = true;
          KeepAlive = false;
          StandardErrorPath = "/var/log/rustdesk-configure.log";
          StandardOutPath = "/var/log/rustdesk-configure.log";
        };
      };
      agents.rustdesk-server = {
        script = ''
          ${configure}/bin/configure-rustdesk --check-app || exit 1
          exec ${appDirectory}/RustDesk --server
        '';
        serviceConfig = {
          Label = "com.carriez.RustDesk_server";
          WorkingDirectory = appDirectory;
          LimitLoadToSessionType = [
            "LoginWindow"
            "Aqua"
          ];
          RunAtLoad = true;
          KeepAlive = {
            SuccessfulExit = false;
            AfterInitialDemand = false;
          };
          ThrottleInterval = 1;
          ProcessType = "Interactive";
        };
      };
    };

    environment.systemPackages = [ configure ];
    # Install this system-wide agent without nix-darwin's root-domain legacy load.
    environment.launchAgents.${agentName}.enable = false;

    # Homebrew installs the app after launchd loads the service definitions.
    system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
      if ! /usr/sbin/chown -R root:wheel /Applications/RustDesk.app 2>/dev/null ||
         ! /bin/chmod -R go-w /Applications/RustDesk.app 2>/dev/null; then
        echo "RustDesk ownership protection failed. Check that the app exists." >&2
        echo "If macOS denied access, allow this terminal in System Settings > Privacy & Security > App Management, then retry activation." >&2
        exit 1
      fi
      ${configure}/bin/configure-rustdesk --check-app

      agent=/Library/LaunchAgents/${agentName}
      agentChanged=false
      if ! /usr/bin/cmp -s ${agentSource} "$agent"; then
        /usr/bin/install -o root -g wheel -m 0644 ${agentSource} "$agent"
        agentChanged=true
      fi
      guiDomain="gui/$(/usr/bin/id -u ${lib.escapeShellArg config.noughty.user.name})"
      if /bin/launchctl print "$guiDomain" >/dev/null 2>&1; then
        if "$agentChanged" && /bin/launchctl print "$guiDomain/com.carriez.RustDesk_server" >/dev/null 2>&1; then
          /bin/launchctl bootout "$guiDomain/com.carriez.RustDesk_server"
        fi
        if ! /bin/launchctl print "$guiDomain/com.carriez.RustDesk_server" >/dev/null 2>&1; then
          /bin/launchctl bootstrap "$guiDomain" "$agent"
        fi
      else
        echo "RustDesk agent will start at the next LoginWindow or Aqua session."
      fi
      ${configure}/bin/configure-rustdesk ${lib.escapeShellArg passwordFile}
    '';
  };
}
