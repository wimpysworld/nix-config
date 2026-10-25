{
  lib,
  host,
  flavour,
}:
{
  "$schema" = "https://opencode.ai/v2/cli.json";
  theme = {
    name =
      if
        lib.elem flavour [
          "frappe"
          "macchiato"
        ]
      then
        "catppuccin-${flavour}"
      else
        "catppuccin";
    mode = if flavour == "latte" then "light" else "dark";
  };
  plugins = lib.optional host.is.linux "./herdr-opencode";
  diffs.view = "unified";
  scroll.acceleration = true;
  keybinds = {
    "app.exit" = "ctrl+d";
    "session.interrupt" = "escape";
    "input.move.up" = "up";
    "input.move.down" = "down";
    "input.move.left" = "left";
    "input.move.right" = "right";
    "prompt.history.previous" = "ctrl+up";
    "prompt.history.next" = "ctrl+down";
    "input.line.home" = "home";
    "input.line.end" = "end";
    "input.buffer.home" = "ctrl+home";
    "input.buffer.end" = "ctrl+end";
    "session.first" = "shift+pageup";
    "session.last" = "shift+pagedown";
    "session.page.up" = "pageup";
    "session.page.down" = "pagedown";
    "session.message.next" = "none";
    "session.message.previous" = "none";
    "input.newline" = "shift+return,ctrl+return";
    "input.submit" = "return";
    "input.select.up" = "shift+up";
    "input.select.down" = "shift+down";
    "input.select.left" = "shift+left";
    "input.select.right" = "shift+right";
    "input.select.line.home" = "shift+home";
    "input.select.line.end" = "shift+end";
    "input.select.buffer.home" = "ctrl+shift+home,ctrl+a";
    "input.select.buffer.end" = "ctrl+shift+end";
    "input.word.forward" = "ctrl+right";
    "input.word.backward" = "ctrl+left";
    "input.select.word.forward" = "ctrl+shift+right";
    "input.select.word.backward" = "ctrl+shift+left";
    "prompt.clear" = "none";
    "prompt.paste" = "ctrl+v,shift+insert,ctrl+shift+v";
    "input.undo" = "ctrl+z";
    "input.redo" = "ctrl+shift+z";
    "input.backspace" = "backspace";
    "input.delete" = "delete";
    "input.delete.word.forward" = "ctrl+delete";
    "input.delete.word.backward" = "ctrl+backspace";
    "input.delete.line" = "ctrl+shift+k";
  };
}
