{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  shellAliases = {
    pq = "${pkgs.pueue}/bin/pueue";
  };
in
lib.mkIf host.is.linux {
  programs = {
    bash.shellAliases = shellAliases;
    fish.shellAliases = shellAliases;
    zsh.shellAliases = shellAliases;
  };

  services = {
    pueue = {
      enable = true;
      # https://github.com/Nukesor/pueue/wiki/Configuration
      settings = {
        daemon = {
          default_parallel_tasks = 1;
          callback = "${pkgs.notify-desktop}/bin/notify-desktop \"Task {{ id }}\nCommand: {{ command }}\nPath: {{ path }}\nFinished with status '{{ result }}'\nTook: $(bc <<< \"{{end}} - {{start}}\") seconds\" --app-name=pueue";
        };
      };
    };
  };
}
