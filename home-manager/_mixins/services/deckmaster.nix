{ hostname, pkgs, username, ... }:
{
  # https://github.com/muesli/deckmaster
  home.packages = with pkgs; [
    deckmaster
  ];

  systemd.user.services = {
    deckmaster-mini = {
      Unit = {
        Description = "Deckmaster Mini";
      };
      Service = {
        ConditionPathIsSymbolicLink = "/dev/streamdeck-mini";
        ConditionPathExist = "/home/${username}/Studio/StreamDeck/Deckmaster-mini/main.deck";
        ExecStart = "${pkgs.deckmaster}/bin/deckmaster -deck /home/${username}/Studio/StreamDeck/Deckmaster-mini/main.deck";
        Restart = "on-failure";
        ExecReload = "kill -HUP $MAINPID";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
    deckmaster = {
      Unit = {
        Description = "Deckmaster";
      };
      Service = {
        ConditionPathIsSymbolicLink = "/dev/streamdeck";
        ConditionPathExist = "/home/${username}/Studio/StreamDeck/Deckmaster/main.deck";
        ExecStart = "${pkgs.deckmaster}/bin/deckmaster -deck /home/${username}/Studio/StreamDeck/Deckmaster/main.deck";
        Restart = "on-failure";
        ExecReload = "kill -HUP $MAINPID";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
    deckmaster-xl = {
      Unit = {
        Description = "Deckmaster XL";
      };
      Service = {
        ConditionPathIsSymbolicLink = "/dev/streamdeck-xl";
        ConditionPathExist = "/home/${username}/Studio/StreamDeck/Deckmaster-xl/main.deck";
        ExecStart = "${pkgs.deckmaster}/bin/deckmaster -deck /home/${username}/Studio/StreamDeck/Deckmaster-xl/main.deck";
        Restart = "on-failure";
        ExecReload = "kill -HUP $MAINPID";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
