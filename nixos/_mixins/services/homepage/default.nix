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
    "none"
  ];
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  sops = {
    secrets = {
      homepage-env = {
        group = "users";
        mode = "0400";
        owner = "root";
        path = "/etc/homepage-dashboard/secrets.env";
        sopsFile = ../../../../secrets/homepage.yaml;
      };
    };
  };
  services = {
    # Reverse proxy homepage-dashboard if Tailscale is enabled.
    caddy.virtualHosts."${hostname}.${tailNet}".extraConfig = lib.mkIf
    (config.services.homepage-dashboard.enable && config.services.tailscale.enable)
      ''
        reverse_proxy localhost:8082
      '';
    homepage-dashboard = {
      enable = true;
      environmentFile = config.sops.secrets.homepage-env.path;
      services = [
        {
          Services = [
            {
              Netdata = lib.mkIf config.services.netdata.enable {
                description = "Netdata Observability";
                icon = "netdata";
                href = "https://${hostname}.${tailNet}/netdata/";
                siteMonitor = "https://${hostname}.${tailNet}/netdata/";
                widget = {
                  type = "netdata";
                  url = "http://localhost:19999";
                  fields = [ "criticals" "warnings" ];
                };
              };
            }
            {
              Scrutiny = lib.mkIf config.services.scrutiny.enable {
                description = "S.M.A.R.T. Monitoring";
                icon = "scrutiny";
                href = "https://${hostname}.${tailNet}/scrutiny/";
                siteMonitor = "https://${hostname}.${tailNet}/scrutiny/";
                widget = {
                  type = "scrutiny";
                  url = "http://localhost:8080/scrutiny";
                  fields = [ "failed" "passed" "unknown" ];
                };
              };
            }
            {
              Jellyfin = lib.mkIf config.services.jellyfin.enable {
                description = "Jellyfin Media Server";
                icon = "jellyfin.png";
                href = "http://${hostname}:8096";
                siteMonitor = "http://${hostname}:8096/web";
                widget = {
                  type = "jellyfin";
                  url = "http://localhost:8096";
                  key = "{{HOMEPAGE_VAR_JELLYFIN_API_KEY}}";
                  enableBlocks = true;              # optional, defaults to false
                  enableNowPlaying = true;          # optional, defaults to true
                  enableUser = true;                # optional, defaults to false
                  showEpisodeNumber = true;         # optional, defaults to false
                  expandOneStreamToTwoRows = true;  # optional, defaults to true
                };
              };
            }
            {
              Plex = lib.mkIf config.services.plex.enable {
                description = "Plex Media Server";
                icon = "plex.png";
                href = "http://${hostname}:32400";
                siteMonitor = "http://${hostname}:32400/web";
                widget = {
                  type = "plex";
                  url = "http://127.0.0.1:32400";
                  # https://www.plexopedia.com/plex-media-server/general/plex-token/
                  # https://www.plex.tv/claim/
                  key = "{{HOMEPAGE_VAR_PLEX_API_KEY}}";
                  fields = [ "streams" "movies" "tv" ];
                };
              };
            }
          ];
        }
        {
          Infra = [
            {
              "tp-link Deco BE85" = {
                description = "Router: Home";
                icon = "tp-link.png";
                href = "http://10.10.10.1";
                siteMonitor = "http://10.10.10.1";
              };
            }
            {
              "Hitron Chita" = {
                description = "Router: Fibre";
                icon = "router";
                href = "http://62.31.16.153";
                siteMonitor = "http://62.31.16.153/webpages/login.html";
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
                href = "http://10.10.10.19";
                siteMonitor = "http://10.10.10.19";
              };
            }
            {
              "Grandstream HT801" = {
                description = "VoIP: Home";
                icon = "voip-info.png";
                href = "http://10.10.10.12";
                siteMonitor = "http://10.10.10.12/cgi-bin/login/";
              };
            }
            {
              "HP Color LaserJet Pro MFP M283fdw" = {
                description = "Printer: Home";
                icon = "hp.png";
                href = "http://10.10.10.11";
                siteMonitor = "http://10.10.10.11";
              };
            }
          ];
        }
        {
          Tailscale = [
            {
              Revan = {
                description = "Home Server";
                icon = "tailscale";
                href = "https://revan.${tailNet}";
                siteMonitor = "https://revan.${tailNet}";
                widget = {
                    type = "tailscale";
                    deviceid = "{{HOMEPAGE_VAR_REVAN_TAILSCALE_DEVICEID}}";
                    key = "{{HOMEPAGE_VAR_TAILSCALE_API_KEY}}";
                    fields = [ "address" "last_seen" "expires" ];
                };
              };
            }
            {
              Malak = {
                description = "Internet Server";
                icon = "tailscale";
                href = "https://malak.${tailNet}";
                siteMonitor = "https://malak.${tailNet}";
                widget = {
                    type = "tailscale";
                    deviceid = "{{HOMEPAGE_VAR_MALAK_TAILSCALE_DEVICEID}}";
                    key = "{{HOMEPAGE_VAR_TAILSCALE_API_KEY}}";
                    fields = [ "address" "last_seen" "expires" ];
                };
              };
            }
            {
              Vader = {
                description = "Home Workstation";
                icon = "tailscale";
                href = "https://vader.${tailNet}";
                siteMonitor = "https://vader.${tailNet}";
                widget = {
                    type = "tailscale";
                    deviceid = "{{HOMEPAGE_VAR_VADER_TAILSCALE_DEVICEID}}";
                    key = "{{HOMEPAGE_VAR_TAILSCALE_API_KEY}}";
                    fields = [ "address" "last_seen" "expires" ];
                };
              };
            }
            {
              Pasma = {
                description = "Office Workstation";
                icon = "tailscale";
                href = "https://phasma.${tailNet}";
                siteMonitor = "https://phasma.${tailNet}";
                widget = {
                    type = "tailscale";
                    deviceid = "{{HOMEPAGE_VAR_PHASMA_TAILSCALE_DEVICEID}}";
                    key = "{{HOMEPAGE_VAR_TAILSCALE_API_KEY}}";
                    fields = [ "address" "last_seen" "expires" ];
                };
              };
            }
            {
              Frontroom = {
                description = "AppleTV: Frontroom";
                icon = "tailscale";
                href = "https://login.tailscale.com/admin/machines";
                widget = {
                    type = "tailscale";
                    deviceid = "{{HOMEPAGE_VAR_FRONTROOM_TAILSCALE_DEVICEID}}";
                    key = "{{HOMEPAGE_VAR_TAILSCALE_API_KEY}}";
                    fields = [ "address" "last_seen" "expires" ];
                };
              };
            }
            {
              Bedroom = {
                description = "AppleTV: Bedroom";
                icon = "tailscale";
                href = "https://login.tailscale.com/admin/machines";
                widget = {
                    type = "tailscale";
                    deviceid = "{{HOMEPAGE_VAR_BEDROOM_TAILSCALE_DEVICEID}}";
                    key = "{{HOMEPAGE_VAR_TAILSCALE_API_KEY}}";
                    fields = [ "address" "last_seen" "expires" ];
                };
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
            #timezone = "Europe/London";
            units = "metric";
          };
        }
      ];
    };
  };
}
