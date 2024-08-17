{
  config,
  hostname,
  inputs,
  lib,
  pkgs,
  platform,
  ...
}:
{
  # gBar is a status bar for Wayland/Hyprland
  imports = [
    inputs.gBar.homeManagerModules.${platform}.default
  ];
  home = {
    packages = with pkgs; [
      pamixer
    ];
  };
  programs = {
    gBar = {
      enable = true;
      # https://github.com/scorpion-26/gBar/blob/master/module.nix
      config = {
        # Sensors
        # TODO: Make this host specific
        BatteryFolder = "/sys/class/power_supply/BAT0";
        CPUThermalZone = "/sys/class/thermal/thermal_zone0/temp";
        DiskPartition = "/";
        DrmAmdCard = "card1";
        SensorTooltips = true;

        # Network
        NetworkAdapter = "wlan0";
        NetworkWidget = true;
        # These set the range for the network widget. The widget changes colors at six intervals:
        MinDownloadBytes = 0;
        MaxDownloadBytes = 104857600; # 100 * 1024 * 1024 = 100 MiB
        MinUploadBytes = 0;
        MaxUploadBytes = 10485760;    #  10 * 1024 * 1024 =  10 MiB
        # Audio
        AudioInput = true;
        AudioRevealer = true;
        AudioScrollSpeed = 5;
        AudioNumbers = false;
        AudioMinVolume = 10;
        AudioMaxVolume = 100;
        # Postion/Layout
        DateTimeStyle = "%a, %d %b %R"; # Fri, 16 Aug 13:37
        DateTimeLocale = "en_GB.utf8";
        Location = "T";
        # SNI (Indicators)
        EnableSNI = true;
        SNIIconSize = {
          Discord = 26;
          OBS = 23;
        };
        # Commands
        ExitCommand = "${pkgs.hyprland}/bin/hyprctl dispatch exit";
        LockCommand = "${lib.getExe pkgs.hyprlock} --immediate";
        SuspendCommand = "${pkgs.unstable.hyprland}/bin/hyprctl dispatch dpms off && ${pkgs.systemd}/bin/systemctl suspend";

        # Workspaces
        DefaultWorkspaceSymbol = "";
        NumWorkspaces = 8;
        WorkspaceScrollOnMonitor = false;
        WorkspaceScrollInvert = false;
        WorkspaceSymbols = [ " " " " " " " " " " " " " " " " ];
        UseHyprlandIPC = config.wayland.windowManager.hyprland.enable;
      };
      # https://github.com/scorpion-26/gBar/blob/master/data/config
      extraConfig = ''
        # extraConfig
        TimeSpace: 256
        CenterSpace: 256
        CenterWidgets: true
        BatteryWarnThreshold: 20
        IconsAlwaysUp: false
        MaxTitleLength: 30
        NetworkIconSize: 24
        SensorSize: 24
        WidgetsLeft: [Workspaces]
        WidgetsCenter: [Time]
        WidgetsRight: [Tray, Disk, VRAM, GPU, RAM, CPU, Audio, Network, Bluetooth, Battery, Power]
        WorkspaceHideUnused: false
        ShutdownIcon: \s
        RebootIcon: 󰑐
        SleepIcon: 󰏤
        LockIcon: 
        ExitIcon: 󰗼
        BTOffIcon: 󰂲
        BTOnIcon: 󰂯
        BTConnectedIcon: 󰂱
        DevKeyboardIcon: 󰌌\s
        DevMouseIcon: 󰍽\s
        DevHeadsetIcon: 󰋋\s
        DevControllerIcon: 󰖺\s
        DevUnknownIcon: \s
        SpeakerMutedIcon: 󰝟
        SpeakerHighIcon: 󰕾
        MicMutedIcon: 󰍭
        MicHighIcon: 󰍬
        PackageOutOfDateIcon: 󰏔\s
        CheckPackagesCommand: "echo -n 0"
        CheckUpdateInterval: 86400
      '';
    };
  };
  wayland.windowManager.hyprland = {
    settings = {
      exec-once = [
        "gBar bar 0"
      ];
    };
  };
}
