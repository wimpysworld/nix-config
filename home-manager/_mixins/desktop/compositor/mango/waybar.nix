{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  cfg = config.wayland.windowManager.mango;
  contract = (import ../../../../../lib/wayland-compositors.nix).compositors.mango;
  tags = import ./tags.nix { inherit host; };
  tagNumbers = lib.range 1 8;
  # SIGRTMIN+8 refreshes the custom/tagN modules.
  signal = 8;
  sync = lib.optionalString tags.synced ",1";
  owners = lib.listToAttrs (
    lib.concatMap (
      n:
      let
        output = tags.outputForTag n;
      in
      lib.optional (output != null) (lib.nameValuePair (toString n) output)
    ) tagNumbers
  );
  mmsg = lib.getExe' cfg.package "mmsg";
  dispatch = command: "${mmsg} dispatch ${lib.escapeShellArg command}";

  watcher = pkgs.writeShellApplication {
    name = "mango-tags-watch";
    runtimeInputs = [
      cfg.package
    ]
    ++ (with pkgs; [
      coreutils
      jq
      systemd
    ]);
    text = ''
      mode=${if tags.synced then "synced" else "pinned"}
      primary=${lib.escapeShellArg host.display.primaryOutput}
      owners=${lib.escapeShellArg (builtins.toJSON owners)}
      signal=${toString signal}
    ''
    + builtins.readFile ./mango-tags-watch.sh;
  };

  mkTagModule =
    n:
    let
      tag = toString n;
      output = tags.outputForTag n;
      fallback = lib.escapeShellArg (builtins.toJSON { text = tag; });
    in
    lib.nameValuePair "custom/tag${tag}" {
      format = "<big>${contract.waybar.tagIcons.${tag}}</big>";
      # The watcher writes one line per tag. Before its first write, the tag
      # shows without a state class.
      exec = "${pkgs.gnused}/bin/sed -n ${tag}p \"$XDG_RUNTIME_DIR/mango-tags\" 2>/dev/null || echo ${fallback}";
      return-type = "json";
      inherit signal;
      tooltip = false;
      on-click = dispatch (
        if output == null then "view,${tag}${sync}" else "viewcrossmon,${tag},^${output}$"
      );
      on-scroll-up = dispatch "viewtoleft${sync}";
      on-scroll-down = dispatch "viewtoright${sync}";
    };
in
lib.mkIf (host.desktop == "mango") {
  compositor.waybar.modules = lib.listToAttrs (map mkTagModule tagNumbers);

  systemd.user.services.mango-tags-watch = {
    Unit = {
      Description = "Mango tag state for Waybar";
      After = [ contract.sessionTarget ];
      PartOf = [ contract.sessionTarget ];
    };
    Service = {
      ExecStart = lib.getExe watcher;
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ contract.sessionTarget ];
  };
}
