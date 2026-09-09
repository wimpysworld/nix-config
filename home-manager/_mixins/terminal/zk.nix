{ lib, ... }:
{
  programs.zk = {
    enable = lib.mkDefault true;
    settings = {
      notebook.dir = lib.mkDefault "~/Notes";
      note = {
        filename = lib.mkDefault "{{id}}";
        extension = lib.mkDefault "md";
        id-length = lib.mkDefault 8;
        id-charset = lib.mkDefault "alphanum";
        id-case = lib.mkDefault "lower";
        template = lib.mkDefault "default.md";
      };
      format.markdown = {
        link-format = lib.mkDefault "markdown";
        link-drop-extension = lib.mkDefault true;
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
