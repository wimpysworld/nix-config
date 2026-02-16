{
  hostname,
  lib,
  pkgs,
  ...
}:
let
  sync-steam-saves = pkgs.writeShellApplication {
    name = "sync-steam-saves";
    runtimeInputs = with pkgs; [
      coreutils
      netcat-gnu
      openssh
      rsync
      notify-desktop
    ];
    text = builtins.readFile ../../scripts/sync-steam-saves/sync-steam-saves.sh;
  };

  # Define the games to back up: { name, source, schedule }
  games = [
    {
      name = "legoworlds";
      source = ".local/share/Steam/steamapps/compatdata/332310/pfx/drive_c/users/steamuser/AppData/Roaming/Warner Bros. Interactive Entertainment/LEGOWorlds/SAVEDGAMES/";
      schedule = "*:0/30"; # Every 30 minutes
    }
    {
      name = "hotshotracing";
      source = ".local/share/Steam/steamapps/compatdata/609920/pfx/drive_c/users/steamuser/AppData/Local/Sumo Digital Ltd/76561198135009171/";
      schedule = "*:42"; # Hourly at minute 42
    }
  ];

  # Generate a systemd user service for a game backup
  mkService = game: {
    "sync-steam-saves-${game.name}" = {
      Unit = {
        Description = "Synchronise Steam saves for ${game.name} from chimeraos";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${sync-steam-saves}/bin/sync-steam-saves ${game.name} ${lib.escapeShellArg game.source}";
      };
    };
  };

  # Generate a systemd user timer for a game backup
  mkTimer = game: {
    "sync-steam-saves-${game.name}" = {
      Unit = {
        Description = "Run sync-steam-saves for ${game.name}";
      };
      Timer = {
        OnCalendar = game.schedule;
        Persistent = true;
        RandomizedDelaySec = 60;
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
in
{
  systemd.user = lib.mkIf (hostname == "vader") {
    services = lib.mkMerge (map mkService games);
    timers = lib.mkMerge (map mkTimer games);
  };
}
