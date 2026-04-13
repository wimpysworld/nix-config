# This file defines overlays
{ inputs, ... }:
let
  unstablePkgsPath = inputs.nixpkgs-unstable.outPath + "/pkgs/by-name";

  # Pinned here for the freshener workflow.
  ollamaVersion = "0.20.6";
  ollamaHash = "sha256-ol+LsKRxOR37Rpwc9/NouwMg0GOpaeh6zmN5quIBgnA=";
  ollamaVendorHash = "sha256-Lc1Ktdqtv2VhJQssk8K1UOimeEjVNvDWePE9WkamCos=";

  # Pinned here for the freshener workflow.
  llamaCppVersion = "8775";
  llamaCppHash = "sha256-oxQUwXgsr8dDY7wqNxdn7tKyGBowjxLO/xJfdb0J9dk=";
  llamaCppNpmDepsHash = "sha256-RAFtsbBGBjteCt5yXhrmHL39rIDJMCFBETgzId2eRRk=";

  # Pinned here for the freshener workflow.
  llamaSwapVersion = "201";
  llamaSwapHash = "sha256-xDToD6DBds9zbf7gJ6mCgZYiz/sdHDIwBZ/WvSIrK70=";
  llamaSwapVendorHash = "sha256-XiDYlw/byu8CWvg4KSPC7m8PGCZXtp08Y1velx4BR8U=";
  llamaSwapUiNpmDepsHash = "sha256-UX2QAfMgNyzQTDsn3c+QnjVshLWvho7jmQ6s2406qHY=";
in
{
  # This one brings our custom packages from the 'pkgs' directory
  localPackages = final: _prev: import ../pkgs final;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifiedPackages =
    final: prev:
    let
      ollamaPackageFile = unstablePkgsPath + "/ol/ollama/package.nix";
      llamaCppPackageFile = unstablePkgsPath + "/ll/llama-cpp/package.nix";

      ollamaSrc = prev.fetchFromGitHub {
        owner = "ollama";
        repo = "ollama";
        tag = "v${ollamaVersion}";
        hash = ollamaHash;
      };

      ollamaCheckFlags = [
        "-skip=^TestPushHandler/unauthorized_push$|^TestPiRun_InstallAndWebSearchLifecycle$|^TestOpenclawRun_ChannelSetupHappensBeforeGatewayRestart$|^TestOpenclawChannelSetupPreflight$"
      ];

      llamaCppSrc = prev.fetchFromGitHub {
        owner = "ggml-org";
        repo = "llama.cpp";
        tag = "b${llamaCppVersion}";
        hash = llamaCppHash;
        leaveDotGit = true;
        postFetch = ''
          git -C "$out" rev-parse --short HEAD > "$out/COMMIT"
          find "$out" -name .git -print0 | xargs -0 rm -rf
        '';
      };

      llamaSwapSrc = prev.fetchFromGitHub {
        owner = "mostlygeek";
        repo = "llama-swap";
        tag = "v${llamaSwapVersion}";
        hash = llamaSwapHash;
        leaveDotGit = true;
        postFetch = ''
          cd "$out"
          git rev-parse HEAD > "$out/COMMIT"
          date -u -d "@$(git log -1 --pretty=%ct)" "+'%Y-%m-%dT%H:%M:%SZ'" > "$out/SOURCE_DATE_EPOCH"
          find "$out" -name .git -print0 | xargs -0 rm -rf
        '';
      };
    in
    rec {
      ollama =
        (final.callPackage ollamaPackageFile {
          acceleration = null;
          inherit
            ollama
            ollama-cuda
            ollama-rocm
            ollama-vulkan
            ;
        }).overrideAttrs
          (_old: {
            version = ollamaVersion;
            src = ollamaSrc;
            vendorHash = ollamaVendorHash;
            checkFlags = ollamaCheckFlags;
          });

      ollama-cuda =
        (final.callPackage ollamaPackageFile {
          acceleration = "cuda";
          inherit
            ollama
            ollama-cuda
            ollama-rocm
            ollama-vulkan
            ;
        }).overrideAttrs
          (_old: {
            version = ollamaVersion;
            src = ollamaSrc;
            vendorHash = ollamaVendorHash;
            checkFlags = ollamaCheckFlags;
          });

      ollama-rocm =
        (final.callPackage ollamaPackageFile {
          acceleration = "rocm";
          inherit
            ollama
            ollama-cuda
            ollama-rocm
            ollama-vulkan
            ;
        }).overrideAttrs
          (_old: {
            version = ollamaVersion;
            src = ollamaSrc;
            vendorHash = ollamaVendorHash;
            checkFlags = ollamaCheckFlags;
          });

      ollama-vulkan =
        (final.callPackage ollamaPackageFile {
          acceleration = "vulkan";
          inherit
            ollama
            ollama-cuda
            ollama-rocm
            ollama-vulkan
            ;
        }).overrideAttrs
          (_old: {
            version = ollamaVersion;
            src = ollamaSrc;
            vendorHash = ollamaVendorHash;
            checkFlags = ollamaCheckFlags;
          });

      llama-cpp =
        (final.callPackage llamaCppPackageFile {
          inherit llama-cpp;
        }).overrideAttrs
          (old: {
            version = llamaCppVersion;
            src = llamaCppSrc;
            npmDepsHash = llamaCppNpmDepsHash;
            npmDeps = prev.fetchNpmDeps {
              name = "llama-cpp-${llamaCppVersion}-npm-deps";
              inherit (old) npmRoot patches;
              src = llamaCppSrc;
              preBuild = ''
                pushd ${old.npmRoot}
              '';
              hash = llamaCppNpmDepsHash;
            };
          });

      llama-cpp-rocm = llama-cpp.override { rocmSupport = true; };
      llama-cpp-vulkan = llama-cpp.override { vulkanSupport = true; };

      llama-swap =
        let
          llamaSwapUi =
            (final.callPackage (unstablePkgsPath + "/ll/llama-swap/ui.nix") { llama-swap = llama-swap; })
            .overrideAttrs
              (old: {
                version = llamaSwapVersion;
                src = llamaSwapSrc;
                npmDepsHash = llamaSwapUiNpmDepsHash;
                npmDeps = prev.fetchNpmDeps {
                  name = "llama-swap-ui-${llamaSwapVersion}-npm-deps";
                  inherit (old) sourceRoot;
                  src = llamaSwapSrc;
                  hash = llamaSwapUiNpmDepsHash;
                };
              });
        in
        (final.callPackage (unstablePkgsPath + "/ll/llama-swap/package.nix") {
          buildGoModule = prev.buildGo126Module;
        }).overrideAttrs
          (old: {
            version = llamaSwapVersion;
            src = llamaSwapSrc;
            vendorHash = llamaSwapVendorHash;
            passthru = (old.passthru or { }) // {
              ui = llamaSwapUi;
            };
            ui = llamaSwapUi;
          });

      # Override Python packages to fix Darwin-specific issues
      python3 = prev.python3.override {
        packageOverrides = _pyfinal: pyprev: {
          # Fix setproctitle test failures on Darwin with multiprocessing fork
          # See: https://github.com/NixOS/nixpkgs/issues/479313
          setproctitle = pyprev.setproctitle.overridePythonAttrs (old: {
            disabledTests =
              (old.disabledTests or [ ])
              ++ prev.lib.optionals prev.stdenv.isDarwin [
                "test_fork_segfault"
                "test_thread_fork_segfault"
              ];
          });
        };
      };

      python313 = prev.python313.override {
        packageOverrides = _pyfinal: pyprev: {
          # Fix setproctitle test failures on Darwin with multiprocessing fork
          # See: https://github.com/NixOS/nixpkgs/issues/479313
          setproctitle = pyprev.setproctitle.overridePythonAttrs (old: {
            disabledTests =
              (old.disabledTests or [ ])
              ++ prev.lib.optionals prev.stdenv.isDarwin [
                "test_fork_segfault"
                "test_thread_fork_segfault"
              ];
          });
        };
      };

      # Fix inetutils build failure on Darwin with clang 21
      # gnulib's error() macro passes dgettext() results as format strings,
      # triggering -Werror,-Wformat-security in openat-die.c
      # See: https://github.com/NixOS/nixpkgs/issues/488689
      inetutils = prev.inetutils.overrideAttrs (
        old:
        prev.lib.optionalAttrs prev.stdenv.isDarwin {
          env = (old.env or { }) // {
            NIX_CFLAGS_COMPILE = toString [
              (old.env.NIX_CFLAGS_COMPILE or "")
              "-Wno-format-security"
            ];
          };
        }
      );

      linuxPackages_6_12 = prev.linuxPackages_6_12.extend (
        _lpself: lpsuper: {
          mwprocapture = lpsuper.mwprocapture.overrideAttrs (_old: rec {
            pname = "mwprocapture";
            subVersion = "4420";
            version = "1.3.${subVersion}";
            src = prev.fetchurl {
              url = "http://www.magewell.com/files/support/ProCaptureForLinux_${version}.tar.gz";
              sha256 = "sha256-aX8vhousQQ48QPgfLjESGbBw26egDB46AmSkruUaM5g=";
            };
          });
        }
      );

      linuxPackages = prev.linuxPackages.extend (
        _lpself: lpsuper: {
          mwprocapture = lpsuper.mwprocapture.overrideAttrs (_old: rec {
            pname = "mwprocapture";
            subVersion = "4429";
            version = "1.3.${subVersion}";
            src = prev.fetchurl {
              url = "https://www.magewell.com/files/drivers/ProCaptureForLinux_${version}.tar.gz";
              sha256 = "sha256-sYwMVEAvYMKCn4DKQiCtnTxd1chMUd0atgswpC+CZ5g=";
            };
          });
        }
      );

      linuxPackages_latest = prev.linuxPackages_latest.extend (
        _lpself: lpsuper: {
          mwprocapture = lpsuper.mwprocapture.overrideAttrs (old: rec {
            pname = "mwprocapture";
            subVersion = "4429";
            version = "1.3.${subVersion}";
            src = prev.fetchurl {
              url = "https://www.magewell.com/files/drivers/ProCaptureForLinux_${version}.tar.gz";
              sha256 = "sha256-sYwMVEAvYMKCn4DKQiCtnTxd1chMUd0atgswpC+CZ5g=";
            };
            meta = old.meta // {
              broken = false;
            };
          });
        }
      );

      # Override rofi-unwrapped to remove desktop entries (this is where they come from!)
      rofi-unwrapped = prev.rofi-unwrapped.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          rm -f $out/share/applications/rofi.desktop
          rm -f $out/share/applications/rofi-theme-selector.desktop
        '';
      });
    };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstablePackages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    };
  };
}
