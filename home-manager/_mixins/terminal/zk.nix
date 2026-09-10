{ lib, pkgs, ... }:
{
  programs.zk = {
    enable = lib.mkDefault true;
    settings = {
      notebook.dir = lib.mkDefault "~/Notes";
      alias = {
        browse = lib.mkDefault ''zk --notebook-dir "$HOME/Notes" -W "$HOME/Notes" edit --interactive "$@"'';
        tagged = lib.mkDefault ''
          case "''${1-}" in
            ""|-*) printf '%s\n' 'Usage: zk tagged TAG [OPTIONS...]' >&2; exit 2 ;;
          esac
          tag=$1
          shift
          zk --notebook-dir "$HOME/Notes" -W "$HOME/Notes" edit --interactive --tag "$tag" "$@"
        '';
      };
      tool = {
        shell = lib.mkDefault pkgs.runtimeShell;
        fzf-options = lib.mkDefault "--tiebreak begin --tabstop 4 --height 100% --layout reverse --no-hscroll --preview-window wrap --multi";
        fzf-preview = lib.mkDefault "${pkgs.bat}/bin/bat --language markdown --style plain --color always --paging never -- {-1}";
        fzf-line = lib.mkDefault ''{{style "title" title-or-path}}{{#each tags}} #{{this}}{{/each}} {{style "understate" body}}'';
      };
      note = {
        filename = lib.mkDefault "{{#if (slug title)}}{{slug title}}{{else}}untitled{{/if}}";
        extension = lib.mkDefault "md";
        template = lib.mkDefault "default.md";
      };
      group.fuzzel.note.filename = lib.mkDefault "{{#if (slug extra.filename-title)}}{{slug extra.filename-title}}{{else}}untitled{{/if}}";
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
