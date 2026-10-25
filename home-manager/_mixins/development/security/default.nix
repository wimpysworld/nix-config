# Semgrep - cross-language static analysis
# Centralised configuration for all IDE and coding tool integrations.
{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  isDeveloper = noughtyLib.userHasTag "developer";
  isWorkstationDeveloper = isDeveloper && host.is.workstation;
in
lib.mkIf isWorkstationDeveloper {
  home.packages = [
    pkgs.gitleaks
    pkgs.grype
    pkgs.hadolint
    pkgs.kube-linter
    pkgs.kubescape
    pkgs.osv-scanner
    pkgs.prowler
    pkgs.semgrep
    pkgs.syft
    pkgs.trivy
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.dockle # requires btrfs-progs and lvm2 (Linux-only)
  ];

  # Claude Code binds one LSP server per extension, so Semgrep is omitted here
  # to let native language servers win the binding race for code files.

  # Fresh Editor - universal static-analysis LSP.
  programs.fresh-editor.settings.universal_lsp.semgrep = {
    command = "${pkgs.semgrep}/bin/semgrep";
    args = [ "lsp" ];
    enabled = true;
    auto_start = true;
    only_features = [ "diagnostics" ];
  };

  # Zed Editor - LSP server and extension
  programs.zed-editor = lib.mkIf config.programs.zed-editor.enable {
    extensions = [ "semgrep" ];
    userSettings.lsp.semgrep = {
      binary = {
        path = "${pkgs.semgrep}/bin/semgrep";
        arguments = [ "lsp" ];
      };
      initialization_options = {
        scan = {
          configuration = [ "auto" ];
          only_git_dirty = false;
        };
      };
    };
  };
}
