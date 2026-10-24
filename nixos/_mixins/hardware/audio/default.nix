{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  username = config.noughty.user.name;
in
lib.mkIf (host.is.workstation && !host.is.iso) {
  # Enable the threadirqs kernel parameter to reduce pipewire/audio latency
  boot = lib.mkIf config.services.pipewire.enable {
    # - Inspired by: https://github.com/musnix/musnix/blob/master/modules/base.nix#L56
    kernelParams = [ "threadirqs" ];
  };

  environment.systemPackages =
    with pkgs;
    [
      alsa-utils
      playerctl
      pulseaudio
      pulsemixer
    ]
    ++ lib.optionals host.is.workstation [
      pwvucontrol
    ];

  services = {
    # https://nixos.wiki/wiki/PipeWire
    # https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-PipeWire#quantum-ranges
    # Debugging
    #  - pw-top                                            # see live stats
    #  - journalctl -b0 --user -u pipewire                 # see logs (spa resync is "bad")
    #  - pw-metadata -n settings 0                         # see current quantums
    #  - pw-metadata -n settings 0 clock.force-quantum 128 # override quantum
    #  - pw-metadata -n settings 0 clock.force-quantum 0   # disable override
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = lib.mkForce false;
      jack.enable = false;
      pulse.enable = true;
      wireplumber = {
        enable = true;
        # https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/alsa.html
        configPackages = [
          (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/90-ssl2.conf" ''
            # Solid State Logic SSL 2 and SSL 2+ USB audio interfaces.
            # Use the HiFi profile and never suspend the nodes, so that
            # playback and capture do not click when a stream starts.
            # The ALSA buffer keeps the PipeWire defaults. If clicks or xruns
            # remain, escalate one step at a time: set api.alsa.headroom = 256,
            # then api.alsa.period-size = 512, then select the pro-audio profile.
            monitor.alsa.rules = [
              {
                matches = [
                  {
                    device.name = "~^alsa_card[.]usb-Solid_State_Logic_SSL_2_?-00$"
                  }
                ]
                actions = {
                  update-props = {
                    device.profile = "HiFi"
                  }
                }
              }
              {
                matches = [
                  # The HiFi sinks and sources.
                  {
                    node.name = "~^alsa_(input|output)[.]usb-Solid_State_Logic_SSL_2_?-00[.]"
                  }
                  # The hidden hardware nodes behind the split HiFi nodes.
                  {
                    node.name = "~^alsa_(input|output)[.]hw_"
                    api.alsa.card.name = "~^SSL 2[+]?$"
                  }
                ]
                actions = {
                  update-props = {
                    session.suspend-timeout-seconds = 0
                  }
                }
              }
              {
                # Mic1 and Mic2 have the same priority by default. Raise Mic1,
                # so that WirePlumber selects microphone input 1 as the default
                # source when no saved choice exists.
                matches = [
                  {
                    node.name = "~^alsa_input[.]usb-Solid_State_Logic_SSL_2_?-00[.]HiFi__Mic1__source$"
                  }
                ]
                actions = {
                  update-props = {
                    priority.session = 2200
                  }
                }
              }
            ]
          '')
        ];
      };
      # All workstations run the graph at 48 kHz, with a minimum quantum of 256
      # frames. The default quantum (1024) and maximum quantum (2048) stay at the
      # PipeWire defaults.
      # https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-PipeWire#quantum-ranges
      extraConfig.pipewire."92-workstation-clock" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.allowed-rates" = [ 48000 ];
          "default.clock.min-quantum" = 256;
        };
      };
      # Stop PulseAudio clients from asking for a smaller buffer than the minimum quantum.
      extraConfig.pipewire-pulse."92-workstation-clock" = {
        "pulse.properties" = {
          "pulse.min.req" = "256/48000";
          "pulse.min.frag" = "256/48000";
          "pulse.min.quantum" = "256/48000";
        };
      };
    };
    pulseaudio.enable = lib.mkForce false;
  };

  # Allow members of the "audio" group to set RT priorities
  security = {
    # Inspired by musnix: https://github.com/musnix/musnix/blob/master/modules/base.nix#L87
    pam.loginLimits = [
      {
        domain = "@audio";
        item = "memlock";
        type = "-";
        value = "unlimited";
      }
      {
        domain = "@audio";
        item = "rtprio";
        type = "-";
        value = "99";
      }
      {
        domain = "@audio";
        item = "nofile";
        type = "soft";
        value = "99999";
      }
      {
        domain = "@audio";
        item = "nofile";
        type = "hard";
        value = "99999";
      }
    ];
    rtkit.enable = true;
  };

  services = {
    udev.extraRules = ''
      # Expose important timers to members of the audio group
      # Inspired by musnix: https://github.com/musnix/musnix/blob/master/modules/base.nix#L94
      KERNEL=="rtc0", GROUP="audio"
      KERNEL=="hpet", GROUP="audio"
      # Allow users in the audio group to change cpu dma latency
      DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"
    '';
  };

  users.users.${username}.extraGroups =
    lib.optional config.security.rtkit.enable "rtkit"
    ++ lib.optional config.services.pipewire.enable "audio";
}
