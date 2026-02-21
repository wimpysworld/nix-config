{
  config,
  ...
}:
let
  inherit (config.noughty) host;
in
{
  networking = {
    hostName = host.name;
    computerName = host.name;
    # extraHosts = ''
    #   127.0.0.3      k3d-k3d.localhost
    #   10.10.10.1     router
    #   10.10.10.2     re550
    #   10.10.10.3     tv-living-room
    #   10.10.10.4     tv-main-bedroom
    #   10.10.10.6     echo-kitchen
    #   10.10.10.7     echo-office
    #   10.10.10.8     echo-agatha
    #   10.10.10.12    Vonage-HT801 vonage
    #   10.10.10.13    LaMetric-LM2144 lametric
    #   10.10.10.15    chimeraos
    #   10.10.10.19    Hue-Bridge-Office hue-bridge-office
    #   10.10.10.20    Elgato_Key_Light_Air_DAD4 keylight-left key-left
    #   10.10.10.21    Elgato_Key_Light_Air_EEE9 keylight-right key-right
    #   10.10.10.22    moodlamp
    #   10.10.10.23    small-lamp-bulb
    # '';
  };
}
