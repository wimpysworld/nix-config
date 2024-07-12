{
  config,
  hostname,
  isInstall,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  useLowLatencyPipewire = hostname == "phasma" || hostname == "vader";
in
{
  # Enable the threadirqs kernel parameter to reduce pipewire/audio latency
  boot = lib.mkIf config.services.pipewire.enable {
    # - Inpired by: https://github.com/musnix/musnix/blob/master/modules/base.nix#L56
    kernelParams = [ "threadirqs" ];
  };

  environment.systemPackages =
    with pkgs;
    lib.optionals isInstall [
      alsa-utils
      playerctl
      pulseaudio
      pulsemixer
    ]
    ++ lib.optionals (isInstall && isWorkstation) [ pwvucontrol ];

  hardware.pulseaudio.enable = lib.mkForce false;

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
      # Enable 32-bit support if driSupport32Bit is true
      alsa.support32Bit = lib.mkForce config.hardware.opengl.driSupport32Bit;
      jack.enable = false;
      pulse.enable = true;
      wireplumber = {
        enable = true;
        # https://stackoverflow.com/questions/24040672/the-meaning-of-period-in-alsa
        # https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/alsa.html#alsa-buffer-properties
        # cat /nix/store/*-wireplumber-*/share/wireplumber/main.lua.d/99-alsa-lowlatency.lua
        # cat /nix/store/*-wireplumber-*/share/wireplumber/wireplumber.conf.d/99-alsa-lowlatency.conf
        configPackages = lib.mkIf useLowLatencyPipewire [
          (pkgs.writeTextDir "share/wireplumber/main.lua.d/99-alsa-lowlatency.lua" ''
            alsa_monitor.rules = {
              {
                matches = {{{ "node.name", "matches", "*_*put.*" }}};
                apply_properties = {
                  ["audio.format"] = "S16LE",
                  ["audio.rate"] = 48000,
                  -- api.alsa.headroom: defaults to 0
                  ["api.alsa.headroom"] = 128,
                  -- api.alsa.period-num: defaults to 2
                  ["api.alsa.period-num"] = 2,
                  -- api.alsa.period-size: defaults to 1024, tweak by trial-and-error
                  ["api.alsa.period-size"] = 512,
                  -- api.alsa.disable-batch: USB audio interface typically use the batch mode
                  ["api.alsa.disable-batch"] = false,
                  ["resample.quality"] = 4,
                  ["resample.disable"] = false,
                  ["session.suspend-timeout-seconds"] = 0,
                },
              },
            }
          '')
        ];
      };
      # https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-PipeWire#quantum-ranges
      extraConfig.pipewire."92-low-latency" = lib.mkIf useLowLatencyPipewire {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 64;
          "default.clock.min-quantum" = 64;
          "default.clock.max-quantum" = 64;
        };
        "context.modules" = [
          {
            name = "libpipewire-module-rt";
            args = {
              "nice.level" = -11;
              "rt.prio" = 88;
            };
          }
        ];
      };
      extraConfig.pipewire-pulse."92-low-latency" = lib.mkIf useLowLatencyPipewire {
        "pulse.properties" = {
          "pulse.default.format" = "S16";
          "pulse.fix.format" = "S16LE";
          "pulse.fix.rate" = "48000";
          "pulse.min.frag" = "64/48000"; # 1.3ms
          "pulse.min.req" = "64/48000"; # 1.3ms
          "pulse.default.frag" = "64/48000"; # 1.3ms
          "pulse.default.req" = "64/48000"; # 1.3ms
          "pulse.max.req" = "64/48000"; # 1.3ms
          "pulse.min.quantum" = "64/48000"; # 1.3ms
          "pulse.max.quantum" = "64/48000"; # 1.3ms
        };
        "stream.properties" = {
          "node.latency" = "64/48000"; # 1.3ms
          "resample.quality" = 4;
          "resample.disable" = false;
        };
      };
    };
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
    # use `lspci -nn`
    udev.extraRules = ''
      # Remove AMD Audio devices; if present
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1002", ATTR{class}=="0xab28", ATTR{power/control}="auto", ATTR{remove}="1"
      # Remove NVIDIA Audio devices; if present
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"
      # Expose important timers the members of the audio group
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
