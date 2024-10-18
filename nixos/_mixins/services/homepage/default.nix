{
  config,
  hostname,
  lib,
  pkgs,
  tailNet,
  ...
}:
let
  installOn = [
    "malak"
    "phasma"
    "revan"
    "shaa"
    "sidious"
    "tanis"
    "vader"
  ];
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  services = {
    # Reverse proxy homepage-dashboard if Tailscale is enabled.
    caddy.virtualHosts."${hostname}.${tailNet}".extraConfig = lib.mkIf
    (config.services.homepage-dashboard.enable && config.services.tailscale.enable)
      ''
        reverse_proxy localhost:8082
      '';
    homepage-dashboard = {
      enable = true;
      package = pkgs.unstable.homepage-dashboard;
      services = [
        {
          Infra = [
            {
              "tp-link AX6000" = {
                description = "Router: Home";
                icon = "tp-link.png";
                href = "http://192.168.2.1";
                siteMonitor = "http://192.168.2.1";
              };
            }
            {
              "GL-iNET Beryl AX (GL-MT3000)" = {
                description = "Router: Travel";
                icon = "router";
                href = "http://192.168.8.1";
                siteMonitor = "http://192.168.8.1";
              };
            }
            {
              "Philips Hue Bridge" = {
                description = "Lights: Home";
                icon = "diyhue.png";
                href = "https://192.168.2.250";
                ping = "https://192.168.2.250";
              };
            }
            {
              "Grandstream HT801" = {
                description = "VoIP: Home";
                icon = "voip-info.png";
                href = "http://192.168.2.58";
                ping = "http://192.168.2.58";
              };
            }
            {
              "HP Color LaserJet Pro MFP M283fdw" = {
                description = "Printer: Home";
                icon = "hp.png";
                href = "http://192.168.2.11";
                siteMonitor = "http://192.168.2.11";
              };
            }
          ];
        }
      ];
      settings = {
        background = {
          image = "https://raw.githubusercontent.com/wimpysworld/nix-config/main/nixos/_mixins/configs/backgrounds/Catppuccin-2560x2880.png";
          blur = "sm"; # sm, md, xl... see https://tailwindcss.com/docs/backdrop-blur
          saturate = "75"; # 0, 50, 100... see https://tailwindcss.com/docs/backdrop-saturate
          brightness = "75"; # 0, 50, 75... see https://tailwindcss.com/docs/backdrop-brightness
          opacity = "100"; # 0-100
        };
        color = "zinc";
        favicon = "https://wimpysworld.com/favicon.ico";
        headerStyle = "boxed";
        hideVersion = true;
        #layout = {
        #  Links = {
        #    style = "row";
        #    columns = 4;
        #  };
        #};
        showStats = true;
        title = "Homepage: ${hostname}";
      };
      widgets = [
        {
          logo = {
            icon = "https://wimpysworld.com/profile.webp";
          };
        }
        #{
        #  datetime = {
        #    format = {
        #      dateStyle = "short";
        #      hourCycle = "h23";
        #      timeStyle = "short";
        #    };
        #  };
        #}
        #{
        #  greeting = {
        #    text_size = "xl";
        #    text = "Greeting Text";
        #  };
        #}
        #{
        #  quicklaunch = {
        #    provider = "custom";
        #    target = "_blank";
        #    url = "https://kagi.com/search?q=";
        #    searchDescriptions = true;
        #    hideInternetSearch = false;
        #    showSearchSuggestions = false;
        #    hideVisitURL = false;
        #  };
        #}
        {
          search = {
            provider = "custom";
            target = "_blank";
            url = "https://kagi.com/search?q=";
          };
        }
        {
          resources = {
            label = "${hostname}";
            cpu = true;
            cputemp = true;
            memory = false;
            refresh = 2000;
            uptime = true;
            units = "metric";
          };
        }
        {
          resources = {
            label = "/";
            disk = [ "/" ];
            diskUnits = "gigabytes";
            expanded = true;
          };
        }
        {
          resources = {
            label = "/home";
            disk = [ "/home" ];
            diskUnits = "gigabytes";
            expanded = true;
          };
        }
        {
          openmeteo = {
            label = "Weather";
            latitude = "51.254383";
            longitude = "-0.939525";
            timezone = "Europe/London";
            units = "metric";
          };
        }
      ];
    };
  };
}
