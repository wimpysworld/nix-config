{
  config,
  lib,
  pkgs,
  ...
}:
let
  launcherFilename = "{{#if (slug extra.filename-title)}}{{slug extra.filename-title}}{{else}}untitled{{/if}}";
  browseEditor = lib.escapeShellArgs [
    (lib.getExe pkgs.markless)
    "--theme"
    "dark"
    "--editor"
    (lib.getExe config.programs.fresh-editor.package)
    "--"
  ];
  repeatBrowseEditor = lib.escapeShellArgs [
    pkgs.runtimeShell
    "-c"
    ''${browseEditor} "$@" && : > "$ZK_BROWSE_OPENED"''
    "--"
  ];
in
{
  home.shellAliases = {
    notes = lib.mkDefault "zk browse";
    todo = lib.mkDefault "zk todo";
    scratch = lib.mkDefault "zk scratch";
    new-note = lib.mkDefault "zk new";
  };

  programs.zk = {
    enable = lib.mkDefault true;
    settings = {
      notebook.dir = lib.mkDefault "~/Notes";
      alias = {
        browse = lib.mkDefault ''
          browseState=$(${pkgs.coreutils}/bin/mktemp -d) || exit
          trap '${pkgs.coreutils}/bin/rm -f -- "$browseState/opened"; ${pkgs.coreutils}/bin/rmdir -- "$browseState"' EXIT
          while true; do
            ${pkgs.coreutils}/bin/rm -f -- "$browseState/opened" || exit
            ZK_BROWSE_OPENED="$browseState/opened" ZK_EDITOR=${lib.escapeShellArg repeatBrowseEditor} ${lib.getExe config.programs.zk.package} --notebook-dir "$HOME/Notes" -W "$HOME/Notes" edit --interactive "$@" || exit $?
            # zk also exits successfully when the picker is cancelled.
            [ -f "$browseState/opened" ] || break
          done
        '';
        tagged = lib.mkDefault ''
          case "''${1-}" in
            ""|-*) printf '%s\n' 'Usage: zk tagged TAG [OPTIONS...]' >&2; exit 2 ;;
          esac
          tag=$1
          shift
          ZK_EDITOR=${lib.escapeShellArg browseEditor} ${lib.getExe config.programs.zk.package} --notebook-dir "$HOME/Notes" -W "$HOME/Notes" edit --interactive --tag "$tag" "$@"
        '';
      };
      tool = {
        shell = lib.mkDefault pkgs.runtimeShell;
        fzf-bind-new = lib.mkDefault "";
        fzf-options = lib.mkDefault (
          "--tiebreak begin --tabstop 4 --height 100% --layout reverse --no-hscroll --preview-window wrap --no-multi"
          + " --header='Ctrl-N: New | Ctrl-S: Scratch | Ctrl-T: ToDo'"
          + " --bind='ctrl-n:become(${lib.getExe config.programs.zk.package} new > /dev/tty)'"
          + " --bind='ctrl-s:become(${lib.getExe config.programs.zk.package} scratch > /dev/tty)'"
          + " --bind='ctrl-t:become(${lib.getExe config.programs.zk.package} todo > /dev/tty)'"
        );
        fzf-preview = lib.mkDefault "${pkgs.bat}/bin/bat --language markdown --style plain --color always --paging never -- {-1}";
        fzf-line = lib.mkDefault ''{{style "title" title-or-path}}{{#each tags}} #{{this}}{{/each}} {{style "understate" body}}'';
      };
      note = {
        exclude = lib.mkDefault [
          "**/.git/**"
          "**/.gitignore"
          "AGENTS.md"
          "CLAUDE.md"
          "README.md"
        ];
        filename = lib.mkDefault "{{#if (slug title)}}{{slug title}}{{else}}untitled{{/if}}";
        extension = lib.mkDefault "md";
        template = lib.mkDefault "default.md";
      };
      group.fuzzel.note.filename = lib.mkDefault launcherFilename;
      group.terminal.note.filename = lib.mkDefault launcherFilename;
      format.markdown = {
        link-format = lib.mkDefault "markdown";
        link-drop-extension = lib.mkDefault false;
        link-encode-path = lib.mkDefault true;
      };
    };
  };

  xdg.configFile."zk/templates/default.md".text = lib.mkDefault ''
    ---
    title: {{json title}}
    date: {{json now}}
    tags: []
    ---

    # {{title}}

    {{content}}
  '';
}
