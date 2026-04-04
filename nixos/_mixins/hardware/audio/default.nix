{
  config,
  noughtyLib,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  username = config.noughty.user.name;
  useLowLatencyPipewire = noughtyLib.hostHasTag "studio";

  # Audio parameters - centralised for consistency across all configs
  sampleRate = 48000;
  # 96 works on Framework Desktop (Ryzen AI MAX); 64 was fine on Ryzen 5000.
  # Must be consistent across pipewire, pipewire-pulse, and wireplumber.
  quantum = 128;
  # Express quantum as a fraction string for pipewire-pulse
  quantumFrac = "${toString quantum}/${toString sampleRate}";
  powerOfTwoQuantum = quantum > 0 && builtins.bitAnd quantum (quantum - 1) == 0;
in
lib.mkIf (!host.is.iso) {
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
      alsa.support32Bit = lib.mkForce config.hardware.graphics.enable32Bit;
      jack.enable = false;
      pulse.enable = true;
      wireplumber = {
        enable = true;
        # https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/alsa.html#alsa-buffer-properties
        configPackages = lib.mkIf useLowLatencyPipewire [
          # Modern WirePlumber .conf format (replaces Lua config)
          (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/99-alsa-lowlatency.conf" ''
            monitor.alsa.rules = [
              {
                matches = [
                  {
                    node.name = "~alsa_*put.*"
                  }
                ]
                actions = {
                  update-props = {
                    audio.rate = ${toString sampleRate}
                    # api.alsa.headroom: extra delay between hw and sw pointers.
                    # Higher values absorb timing jitter from USB batch devices.
                    api.alsa.headroom = ${toString quantum}
                    # api.alsa.period-num: number of periods in the hw buffer.
                    api.alsa.period-num = 2
                    # api.alsa.period-size: controls IRQ frequency (period-size/2 for batch).
                    # Should be >= quantum. For batch USB devices, effective period is half this.
                    api.alsa.period-size = ${toString (quantum * 2)}
                    # USB audio interfaces are typically batch devices; keep default behaviour
                    api.alsa.disable-batch = false
                    resample.quality = 10
                    resample.disable = false
                    session.suspend-timeout-seconds = 0
                  }
                }
              }
            ]
          '')
        ];
      };
      # https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-PipeWire#quantum-ranges
      extraConfig.pipewire."92-low-latency" = lib.mkIf useLowLatencyPipewire {
        "context.properties" = {
          # OPTIONAL: uncomment to avoid resampling 44.1kHz content
          "default.clock.allowed-rates" = [ 44100 48000 ];
          "default.clock.rate" = sampleRate;
          # Disable power-of-two rounding so non-PoT quantums (96) work correctly
          "clock.power-of-two-quantum" = powerOfTwoQuantum;
          "default.clock.quantum" = quantum;
          "default.clock.min-quantum" = quantum;
          "default.clock.max-quantum" = quantum;
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
          "pulse.fix.rate" = "${toString sampleRate}";
          # All pulse quantum/frag values must match or exceed the pipewire quantum
          "pulse.min.frag" = quantumFrac;
          "pulse.min.req" = quantumFrac;
          "pulse.default.frag" = quantumFrac;
          "pulse.default.req" = quantumFrac;
          "pulse.max.req" = quantumFrac;
          "pulse.min.quantum" = quantumFrac;
          "pulse.max.quantum" = quantumFrac;
        };
        "stream.properties" = {
          "node.latency" = quantumFrac;
          "resample.quality" = 10;
          "resample.disable" = false;
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
    # use `lspci -nn`
    udev.extraRules = ''
      # Remove AMD Audio devices; if present
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1002", ATTR{class}=="0xab28", ATTR{power/control}="auto", ATTR{remove}="1"
      # Remove NVIDIA Audio devices; if present
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"
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
