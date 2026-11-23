# Reverse Engineer Anything (rea) with Kuna v1.1000 as the default native
# analysis provider and Ghidra 12.2 (with JDK 25) available on demand via
# `--provider ghidra` or MCP `provider_id: "ghidra"`.
#
# The `rea --mcp` server is intentionally not registered in the shared MCP
# catalogue (`../mcp/servers.nix`), so it stays disabled in LibreChat, Zed,
# Moltis, and default `<harness>-fenced` sessions. Instead, each coding harness
# exposes an opt-in `<harness>-fenced-rea` wrapper that attaches `rea --mcp`
# for that session only.
{
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (pkgs.stdenv.hostPlatform) system;
  cfg = config.agentic.rea;
  isDeveloper = noughtyLib.userHasTag "developer";
  supportedSystems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
  reaUpstreamPackage = inputs.llm-agents.packages.${system}.rea;
  kunaPackage = pkgs.kuna-bin;
  # Use the prebuilt official release on x86_64-linux and the source-built
  # package on aarch64-linux so the host-matching native decompiler is present.
  ghidraPackage = if pkgs.stdenv.hostPlatform.isx86_64 then pkgs.ghidra-bin else pkgs.ghidra;
  # Reuse the exact JDK 25 derivation that Ghidra 12.2 wraps so `rea doctor`
  # validates a host-native 64-bit JDK without altering the global JAVA_HOME.
  openjdkPackage = pkgs.unstable.openjdk25;
  # Audited jadx-headless-mcp 0.7.1 release JAR verified by REA 6.10.1.
  jadxHeadlessMcpJar = pkgs.fetchurl {
    url = "https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.7.1/jadx-headless-mcp-0.7.1-all.jar";
    hash = "sha256-bl6s9QC2QpK/tzxJeXwZWPbuRGRuQ+hoA5rn/rVz/3U=";
  };
  prlimitBin = lib.getExe' pkgs.util-linux "prlimit";

  reaWrappedPackage = pkgs.symlinkJoin {
    name = "rea-${reaUpstreamPackage.version}";
    paths = [ reaUpstreamPackage ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for command in rea rea-agents; do
        if [ -e "$out/bin/$command" ]; then
          rm "$out/bin/$command"
          makeWrapper "${reaUpstreamPackage}/bin/$command" "$out/bin/$command" \
            --set-default REA_ANALYSIS_PROVIDER "kuna" \
            --set-default REA_KUNA_COMMAND "${lib.getExe kunaPackage}" \
            --set-default GHIDRA_INSTALL_DIR "${ghidraPackage}/lib/ghidra" \
            --set-default JAVA_HOME "${openjdkPackage.home}" \
            --set-default REA_TSHARK_COMMAND "${lib.getExe' pkgs.wireshark-cli "tshark"}" \
            --set-default REA_CAPINFOS_COMMAND "${lib.getExe' pkgs.wireshark-cli "capinfos"}" \
            --set-default REA_TSHARK_PRLIMIT_COMMAND "${prlimitBin}" \
            --set-default REA_JAVASCRIPT_PRLIMIT_COMMAND "${prlimitBin}" \
            --set-default REA_FIRMWARE_PRLIMIT_COMMAND "${prlimitBin}" \
            --set-default REA_EVM_PRLIMIT_COMMAND "${prlimitBin}" \
            --set-default REA_SIGROK_PRLIMIT_COMMAND "${prlimitBin}" \
            --set-default REA_BINWALK_COMMAND "${lib.getExe pkgs.binwalk}" \
            --set-default REA_UNBLOB_COMMAND "${lib.getExe pkgs.unblob}" \
            --set-default REA_OBJDUMP_COMMAND "${lib.getExe' pkgs.binutils-unwrapped "objdump"}" \
            --set-default REA_GDB_COMMAND "${lib.getExe pkgs.gdb}" \
            --set-default REA_RIZIN_COMMAND "${lib.getExe pkgs.rizin}" \
            --set-default REA_MITMDUMP_COMMAND "${lib.getExe' pkgs.mitmproxy "mitmdump"}" \
            --set-default REA_APKTOOL_COMMAND "${lib.getExe pkgs.apktool}" \
            --set-default REA_ADB_PATH "${lib.getExe' pkgs.android-tools "adb"}" \
            --set-default REA_JADX_MCP_JAR "${jadxHeadlessMcpJar}" \
            --set-default REA_WABT_BIN_DIRECTORY "${pkgs.wabt}/bin" \
            --set-default REA_SIGROK_COMMAND "${lib.getExe pkgs.sigrok-cli}" \
            --prefix PATH : "${lib.makeBinPath [ openjdkPackage ]}"
        fi
      done
    '';
    meta = reaUpstreamPackage.meta // {
      mainProgram = "rea";
    };
  };
in
{
  options.agentic.rea = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = isDeveloper && host.is.workstation && host.is.linux && lib.elem system supportedSystems;
      description = "Whether to enable Reverse Engineer Anything (rea) with Kuna and Ghidra 12.2.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = reaWrappedPackage;
      defaultText = lib.literalExpression "reaWrappedPackage";
      description = "Wrapped Reverse Engineer Anything (rea) package with Kuna default and Ghidra 12.2 fallback.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
      kunaPackage
      ghidraPackage
      pkgs.android-tools
      pkgs.apktool
      pkgs.binwalk
      pkgs.gdb
      pkgs.jadx
      pkgs.mitmproxy
      pkgs.rizin
      pkgs.sigrok-cli
      pkgs.unblob
      pkgs.wabt
      pkgs.wireshark-cli
    ];
  };
}
