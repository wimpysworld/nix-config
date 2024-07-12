{
  config,
  hostname,
  lib,
  pkgs,
  username,
  ...
}:
let
  installOn = [
    "phasma"
    "vader"
  ];
in
lib.mkIf (lib.elem hostname installOn) {
  dconf.settings = with lib.hm.gvariant; {
    "com/github/wwmm/easyeffects" = {
      bypass = false;
      process-all-inputs = false;
      process-all-outputs = false;
      show-native-plugin-ui = true;
      use-cubic-volumes = false;
    };

    "com/github/wwmm/easyeffects/spectrum" = {
      height = 240;
      line-width = mkDouble 2.0;
      n-points = 100;
      rounded-corners = true;
      show-bar-border = true;
      type = "Bars";
    };

    "com/github/wwmm/easyeffects/streaminputs" = {
      blocklist = [ "input.Mic-Loopback" ];
      use-default-input-device = true;
    };

    "com/github/wwmm/easyeffects/streamoutputs" = {
      blocklist = [ "output.Mic-Loopback" ];
    };

    "org/gnome/SoundRecorder" = {
      audio-channel = "mono";
      audio-profile = "flac";
    };
  };

  home.file = {
    "${config.xdg.configHome}/easyeffects/input/mic-vader-oktava.json" = {
      text = ''
        {
            "input": {
                "blocklist": [
                    "input.Mic-Loopback"
                ],
                "compressor#0": {
                    "attack": 10.0,
                    "boost-amount": 6.0,
                    "boost-threshold": -72.0,
                    "bypass": false,
                    "dry": -100.0,
                    "hpf-frequency": 75.0,
                    "hpf-mode": "off",
                    "input-gain": 0.0,
                    "knee": -20.0,
                    "lpf-frequency": 20000.0,
                    "lpf-mode": "off",
                    "makeup": 6.0,
                    "mode": "Downward",
                    "output-gain": 0.0,
                    "ratio": 3.0,
                    "release": 60.0,
                    "release-threshold": -100.0,
                    "sidechain": {
                        "lookahead": 0.0,
                        "mode": "RMS",
                        "preamp": 0.0,
                        "reactivity": 10.0,
                        "source": "Middle",
                        "stereo-split-source": "Left/Right",
                        "type": "Feed-forward"
                    },
                    "stereo-split": false,
                    "threshold": -18.0,
                    "wet": 0.0
                },
                "deepfilternet#0": {
                    "attenuation-limit": 100.0,
                    "max-df-processing-threshold": 20.0,
                    "max-erb-processing-threshold": 30.0,
                    "min-processing-buffer": 0,
                    "min-processing-threshold": -10.0,
                    "post-filter-beta": 0.02
                },
                "deesser#0": {
                    "bypass": false,
                    "detection": "RMS",
                    "f1-freq": 6000.0,
                    "f1-level": 0.0,
                    "f2-freq": 4500.0,
                    "f2-level": 12.0,
                    "f2-q": 1.0,
                    "input-gain": 0.0,
                    "laxity": 15,
                    "makeup": 0.0,
                    "mode": "Wide",
                    "output-gain": 0.0,
                    "ratio": 3.0,
                    "sc-listen": false,
                    "threshold": -30.0
                },
                "filter#0": {
                    "balance": 0.0,
                    "bypass": false,
                    "equal-mode": "IIR",
                    "frequency": 75.0,
                    "gain": 0.0,
                    "input-gain": 0.0,
                    "mode": "RLC (BT)",
                    "output-gain": 0.0,
                    "quality": 1.0,
                    "slope": "x2",
                    "type": "High-pass",
                    "width": 4.0
                },
                "gate#0": {
                    "attack": 5.0,
                    "bypass": false,
                    "curve-threshold": -50.00000000000007,
                    "curve-zone": -6.0,
                    "dry": -100.0,
                    "hpf-frequency": 75.0,
                    "hpf-mode": "off",
                    "hysteresis": false,
                    "hysteresis-threshold": -12.0,
                    "hysteresis-zone": -6.0,
                    "input-gain": 0.0,
                    "lpf-frequency": 20000.0,
                    "lpf-mode": "off",
                    "makeup": 0.0,
                    "output-gain": 0.0,
                    "reduction": -24.0,
                    "release": 50.0,
                    "sidechain": {
                        "input": "Internal",
                        "lookahead": 0.0,
                        "mode": "RMS",
                        "preamp": 0.0,
                        "reactivity": 10.0,
                        "source": "Middle",
                        "stereo-split-source": "Left/Right"
                    },
                    "stereo-split": false,
                    "wet": 0.0
                },
                "limiter#0": {
                    "alr": false,
                    "alr-attack": 5.0,
                    "alr-knee": 0.0,
                    "alr-release": 50.0,
                    "attack": 5.0,
                    "bypass": false,
                    "dithering": "None",
                    "external-sidechain": false,
                    "gain-boost": false,
                    "input-gain": 0.0,
                    "lookahead": 5.0,
                    "mode": "Herm Thin",
                    "output-gain": 0.0,
                    "oversampling": "None",
                    "release": 5.0,
                    "sidechain-preamp": 0.0,
                    "stereo-link": 100.0,
                    "threshold": -1.5
                },
                "plugins_order": [
                    "stereo_tools#0",
                    "deepfilternet#0",
                    "gate#0",
                    "speex#0",
                    "compressor#0",
                    "filter#0",
                    "deesser#0",
                    "limiter#0"
                ],
                "speex#0": {
                    "bypass": false,
                    "enable-agc": false,
                    "enable-denoise": false,
                    "enable-dereverb": true,
                    "input-gain": 0.0,
                    "noise-suppression": -70,
                    "output-gain": 0.0,
                    "vad": {
                        "enable": false,
                        "probability-continue": 90,
                        "probability-start": 95
                    }
                },
                "stereo_tools#0": {
                    "balance-in": 0.0,
                    "balance-out": 0.0,
                    "bypass": false,
                    "delay": 0.0,
                    "input-gain": 0.0,
                    "middle-level": 0.0,
                    "middle-panorama": 0.0,
                    "mode": "LR > LL (Mono Left Channel)",
                    "mutel": false,
                    "muter": false,
                    "output-gain": 0.0,
                    "phasel": false,
                    "phaser": false,
                    "sc-level": 1.0,
                    "side-balance": 0.0,
                    "side-level": 0.0,
                    "softclip": false,
                    "stereo-base": 0.0,
                    "stereo-phase": 0.0
                }
            }
        }
      '';
    };

    "${config.xdg.configHome}/easyeffects/input/mic-phasma-oktava.json" = {
      text = ''
        {
            "input": {
                "blocklist": [
                    "input.Mic-Loopback"
                ],
                "compressor#0": {
                    "attack": 10.0,
                    "boost-amount": 6.0,
                    "boost-threshold": -72.0,
                    "bypass": false,
                    "dry": -100.0,
                    "hpf-frequency": 75.0,
                    "hpf-mode": "off",
                    "input-gain": 0.0,
                    "knee": -20.0,
                    "lpf-frequency": 20000.0,
                    "lpf-mode": "off",
                    "makeup": 6.0,
                    "mode": "Downward",
                    "output-gain": 0.0,
                    "ratio": 3.0,
                    "release": 60.0,
                    "release-threshold": -100.0,
                    "sidechain": {
                        "lookahead": 0.0,
                        "mode": "RMS",
                        "preamp": 0.0,
                        "reactivity": 10.0,
                        "source": "Middle",
                        "stereo-split-source": "Left/Right",
                        "type": "Feed-forward"
                    },
                    "stereo-split": false,
                    "threshold": -18.0,
                    "wet": 0.0
                },
                "deepfilternet#0": {
                    "attenuation-limit": 100.0,
                    "max-df-processing-threshold": 20.0,
                    "max-erb-processing-threshold": 30.0,
                    "min-processing-buffer": 0,
                    "min-processing-threshold": -10.0,
                    "post-filter-beta": 0.02
                },
                "deesser#0": {
                    "bypass": false,
                    "detection": "RMS",
                    "f1-freq": 6000.0,
                    "f1-level": 0.0,
                    "f2-freq": 4500.0,
                    "f2-level": 12.0,
                    "f2-q": 1.0,
                    "input-gain": 0.0,
                    "laxity": 15,
                    "makeup": 0.0,
                    "mode": "Wide",
                    "output-gain": 0.0,
                    "ratio": 3.0,
                    "sc-listen": false,
                    "threshold": -30.0
                },
                "filter#0": {
                    "balance": 0.0,
                    "bypass": false,
                    "equal-mode": "IIR",
                    "frequency": 75.0,
                    "gain": 0.0,
                    "input-gain": 0.0,
                    "mode": "RLC (BT)",
                    "output-gain": 0.0,
                    "quality": 1.0,
                    "slope": "x2",
                    "type": "High-pass",
                    "width": 4.0
                },
                "gate#0": {
                    "attack": 5.0,
                    "bypass": false,
                    "curve-threshold": -40.0,
                    "curve-zone": -6.0,
                    "dry": -100.0,
                    "hpf-frequency": 75.0,
                    "hpf-mode": "off",
                    "hysteresis": false,
                    "hysteresis-threshold": -12.0,
                    "hysteresis-zone": -6.0,
                    "input-gain": 0.0,
                    "lpf-frequency": 20000.0,
                    "lpf-mode": "off",
                    "makeup": 0.0,
                    "output-gain": 0.0,
                    "reduction": -36.0,
                    "release": 50.0,
                    "sidechain": {
                        "input": "Internal",
                        "lookahead": 0.0,
                        "mode": "RMS",
                        "preamp": 0.0,
                        "reactivity": 10.0,
                        "source": "Middle",
                        "stereo-split-source": "Left/Right"
                    },
                    "stereo-split": false,
                    "wet": 0.0
                },
                "limiter#0": {
                    "alr": false,
                    "alr-attack": 5.0,
                    "alr-knee": 0.0,
                    "alr-release": 50.0,
                    "attack": 5.0,
                    "bypass": false,
                    "dithering": "None",
                    "external-sidechain": false,
                    "gain-boost": false,
                    "input-gain": 0.0,
                    "lookahead": 5.0,
                    "mode": "Herm Thin",
                    "output-gain": 0.0,
                    "oversampling": "None",
                    "release": 5.0,
                    "sidechain-preamp": 0.0,
                    "stereo-link": 100.0,
                    "threshold": -1.5
                },
                "plugins_order": [
                    "stereo_tools#0",
                    "deepfilternet#0",
                    "gate#0",
                    "speex#0",
                    "compressor#0",
                    "filter#0",
                    "deesser#0",
                    "limiter#0"
                ],
                "speex#0": {
                    "bypass": false,
                    "enable-agc": false,
                    "enable-denoise": false,
                    "enable-dereverb": true,
                    "input-gain": 0.0,
                    "noise-suppression": -70,
                    "output-gain": 0.0,
                    "vad": {
                        "enable": false,
                        "probability-continue": 90,
                        "probability-start": 95
                    }
                },
                "stereo_tools#0": {
                    "balance-in": 0.0,
                    "balance-out": 0.0,
                    "bypass": false,
                    "delay": 0.0,
                    "input-gain": 0.0,
                    "middle-level": 0.0,
                    "middle-panorama": 0.0,
                    "mode": "LR > LL (Mono Left Channel)",
                    "mutel": false,
                    "muter": false,
                    "output-gain": 0.0,
                    "phasel": false,
                    "phaser": false,
                    "sc-level": 1.0,
                    "side-balance": 0.0,
                    "side-level": 0.0,
                    "softclip": false,
                    "stereo-base": 0.0,
                    "stereo-phase": 0.0
                }
            }
        }
      '';
    };
  };

  home.packages = with pkgs; [
    gnome.gnome-sound-recorder
    tenacity
  ];

  services.easyeffects = {
    enable = true;
    preset = "mic-${hostname}-oktava";
  };

  systemd.user.tmpfiles.rules = [
    "d ${config.home.homeDirectory}/Audio 0755 ${username} users - -"
    "L+ ${config.home.homeDirectory}/.local/share/org.gnome.SoundRecorder/ - - - - ${config.home.homeDirectory}/Audio/"
  ];
}
