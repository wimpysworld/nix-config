{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf host.is.laptop {
  # captive-browser: Go tool that starts a local SOCKS5 proxy using
  # DHCP-provided DNS (bypassing systemd-resolved and DoT), then launches
  # a browser through that proxy for portal login.
  programs.captive-browser = {
    enable = true;
    browser = ''
      env XDG_CONFIG_HOME="$PREV_CONFIG_HOME" ${pkgs.chromium}/bin/chromium \
        --user-data-dir=''${XDG_DATA_HOME:-$HOME/.local/share}/chromium-captive \
        --proxy-server="socks5://$PROXY" \
        --host-resolver-rules="MAP * ~NOTFOUND , EXCLUDE localhost" \
        --no-first-run --new-window --incognito \
        -no-default-browser-check http://neverssl.com
    '';
    # With iwd as the wifi backend, the first wireless interface is named
    # wlan0 by iwd convention. For hosts with multiple wireless adapters,
    # override per-host: programs.captive-browser.interface = "wlan1";
    interface = "wlan0";
  };

  networking.networkmanager = {
    # NetworkManager dispatcher script: on PORTAL state, disable DoT to stop
    # TLS retries causing intermittent DNS failures (see section 2.1 and 7),
    # send a desktop notification, and launch captive-browser. On FULL state,
    # re-enable DoT.
    dispatcherScripts = [
      {
        source = pkgs.writeText "90-captive-portal" ''
          #!/bin/sh
          # Captive portal handler for NetworkManager dispatcher
          # Triggers on connectivity-change events

          LOGGER="${pkgs.util-linux}/bin/logger -s -t captive-portal"

          case "$2" in
            connectivity-change)
              $LOGGER "Connectivity change: $CONNECTIVITY_STATE"

              if [ "$CONNECTIVITY_STATE" = "PORTAL" ]; then
                $LOGGER "Captive portal detected"

                # Find the active wifi interface dynamically instead of
                # hardcoding; handles iwd naming and multiple adapters
                WIFI_IFACE=$(${pkgs.networkmanager}/bin/nmcli -t -f DEVICE,TYPE device status | ${pkgs.gnugrep}/bin/grep ':wifi$' | ${pkgs.coreutils}/bin/head -n1 | ${pkgs.coreutils}/bin/cut -d: -f1)

                if [ -n "$WIFI_IFACE" ]; then
                  # Disable DoT so the portal DNS works reliably and TLS retries
                  # stop causing intermittent resolution failures
                  ${pkgs.systemd}/bin/resolvectl dnsovertls "$WIFI_IFACE" no
                  $LOGGER "Disabled DoT on $WIFI_IFACE"
                fi

                # Send a notification and launch captive-browser for all
                # graphical sessions. Uses systemd-run --user --machine= to
                # correctly enter the user's systemd scope (not runuser -l,
                # which resets the environment).
                for SESSION_ID in $(${pkgs.systemd}/bin/loginctl list-sessions --no-legend | ${pkgs.gawk}/bin/awk '{print $1}'); do
                  SESSION_USER=$(${pkgs.systemd}/bin/loginctl show-session "$SESSION_ID" -p Name --value)
                  SESSION_TYPE=$(${pkgs.systemd}/bin/loginctl show-session "$SESSION_ID" -p Type --value)

                  if [ "$SESSION_TYPE" = "wayland" ] || [ "$SESSION_TYPE" = "x11" ]; then
                    USER_ID=$(${pkgs.coreutils}/bin/id -u "$SESSION_USER")
                    RUNTIME_DIR="/run/user/$USER_ID"

                    if [ -d "$RUNTIME_DIR" ]; then
                      # Notify the user; notify-desktop does not support actions,
                      # so the notification is informational only
                      ${pkgs.systemd}/bin/systemd-run --user --machine="$SESSION_USER@.host" \
                        --setenv=DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus" \
                        ${pkgs.notify-desktop}/bin/notify-desktop \
                          --urgency=critical \
                          --icon=network-wireless \
                          "Captive Portal Detected" \
                          "Opening login page" 2>/dev/null || true

                      # Launch captive-browser, which handles DNS bypass via its
                      # own SOCKS proxy independently of system DNS settings.
                      # No timeout - the browser process runs independently.
                      ${pkgs.systemd}/bin/systemd-run --user --machine="$SESSION_USER@.host" \
                        --setenv=DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus" \
                        --setenv=XDG_RUNTIME_DIR="$RUNTIME_DIR" \
                        captive-browser 2>/dev/null || true
                    fi
                  fi
                done
              fi

              if [ "$CONNECTIVITY_STATE" = "FULL" ]; then
                # Re-enable DoT when connectivity is restored
                WIFI_IFACE=$(${pkgs.networkmanager}/bin/nmcli -t -f DEVICE,TYPE device status | ${pkgs.gnugrep}/bin/grep ':wifi$' | ${pkgs.coreutils}/bin/head -n1 | ${pkgs.coreutils}/bin/cut -d: -f1)

                if [ -n "$WIFI_IFACE" ]; then
                  ${pkgs.systemd}/bin/resolvectl dnsovertls "$WIFI_IFACE" opportunistic
                  $LOGGER "Re-enabled DoT on $WIFI_IFACE"
                fi
              fi
              ;;
            *) exit 0 ;;
          esac
        '';
        type = "basic";
      }
    ];

    # Canonical NetworkManager check endpoint. Returns a known string on success;
    # any portal redirect produces a different response, reliably triggering the
    # PORTAL state. Replaces the previous http://google.cn/generate_204 which
    # may be geo-blocked or redirected on some networks.
    settings.connectivity = {
      uri = lib.mkDefault "http://nmcheck.gnome.org/check_network_status.txt";
      response = lib.mkDefault "NetworkManager is online";
    };
  };
}
