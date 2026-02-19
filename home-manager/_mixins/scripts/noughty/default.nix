{ config, pkgs, ... }:
let
  cfg = config.noughty;
  name = builtins.baseNameOf (builtins.toString ./.);

  # Bake noughty values into shell variables for the facts subcommand
  factsEnv = ''
    # Noughty facts - baked at build time from config.noughty.*
    NOUGHTY_HOST_NAME="${cfg.host.name}"
    NOUGHTY_HOST_KIND="${cfg.host.kind}"
    NOUGHTY_HOST_PLATFORM="${cfg.host.platform}"
    NOUGHTY_HOST_OS="${cfg.host.os}"
    NOUGHTY_HOST_DESKTOP="${if cfg.host.desktop != null then cfg.host.desktop else "none"}"
    NOUGHTY_HOST_FORM_FACTOR="${if cfg.host.formFactor != null then cfg.host.formFactor else "none"}"
    NOUGHTY_HOST_TAGS="${builtins.concatStringsSep " " cfg.host.tags}"
    NOUGHTY_HOST_GPU_VENDORS="${builtins.concatStringsSep " " cfg.host.gpu.vendors}"
    NOUGHTY_HOST_GPU_COMPUTE_VENDOR="${
      if cfg.host.gpu.compute.vendor != null then cfg.host.gpu.compute.vendor else ""
    }"
    NOUGHTY_HOST_GPU_COMPUTE_VRAM="${toString cfg.host.gpu.compute.vram}"
    NOUGHTY_HOST_GPU_COMPUTE_UNIFIED="${if cfg.host.gpu.compute.unified then "true" else "false"}"
    NOUGHTY_HOST_GPU_COMPUTE_ACCEL="${
      if cfg.host.gpu.compute.acceleration != null then cfg.host.gpu.compute.acceleration else ""
    }"
    NOUGHTY_HOST_IS_WORKSTATION="${if cfg.host.is.workstation then "true" else "false"}"
    NOUGHTY_HOST_IS_SERVER="${if cfg.host.is.server then "true" else "false"}"
    NOUGHTY_HOST_IS_LAPTOP="${if cfg.host.is.laptop then "true" else "false"}"
    NOUGHTY_HOST_IS_VM="${if cfg.host.is.vm then "true" else "false"}"
    NOUGHTY_HOST_IS_ISO="${if cfg.host.is.iso then "true" else "false"}"
    NOUGHTY_HOST_IS_DARWIN="${if cfg.host.is.darwin then "true" else "false"}"
    NOUGHTY_HOST_IS_LINUX="${if cfg.host.is.linux then "true" else "false"}"
    NOUGHTY_HOST_DISPLAY_PRIMARY="${cfg.host.display.primaryOutput}"
    NOUGHTY_HOST_DISPLAY_RESOLUTION="${cfg.host.display.primaryResolution}"
    NOUGHTY_HOST_DISPLAY_MULTI="${if cfg.host.display.isMultiMonitor then "true" else "false"}"
    NOUGHTY_HOST_DISPLAY_OUTPUTS="${builtins.concatStringsSep " " cfg.host.display.outputs}"
    NOUGHTY_USER_NAME="${cfg.user.name}"
    NOUGHTY_USER_TAGS="${builtins.concatStringsSep " " cfg.user.tags}"
    NOUGHTY_NETWORK_TAILNET="${cfg.network.tailNet}"
  '';

  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      coreutils
      git
      gnugrep
      gnused
      nix-output-monitor
      util-linux
      which
    ];
    text = factsEnv + builtins.readFile ./${name}.sh;
  };
  shellAliases = {
    nofx = "noughty facts";
    norm = "noughty channel";
    nook = "noughty path";
    nope = "noughty spawn";
    nosh = "noughty shell";
    nout = "noughty run";
  };
in
{
  home.packages = [ shellApplication ];
  programs = {
    bash = {
      inherit shellAliases;
    };
    fish = {
      inherit shellAliases;
    };
    zsh = {
      inherit shellAliases;
    };
  };
}
