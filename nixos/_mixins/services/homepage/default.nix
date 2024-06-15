{ config, desktop, hostname, pkgs, ... }:
let
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
in
{
  services = {
    homepage-dashboard = {
      enable = isInstall;
      environmentFile = config.sops.secrets.homepage-env.path;
      package = pkgs.unstable.homepage-dashboard;
      bookmarks = [
        {
        Development = [
          {
            GitHub = [
              {
                abbr = "GH";
                href = "https://github.com/flexiondotorg";
                icon = "github-light.png";
              }
            ];
          }
          {
            GitLab = [
              {
                abbr = "GL";
                href = "https://gitlab.com";
                icon = "gitlab.png";
              }
            ];
          }
          {
            FlakeHub = [
              {
                abbr = "FH";
                href = "https://flakehub.com";
                icon = "https://flakehub.com/favicon.png";
              }
            ];
          }
          {
            Launchpad = [
              {
                abbr = "LP";
                href = "https://launchpad.net/~flexiondotorg";
                icon = "https://launchpad.net/@@/favicon-32x32.png?v=2022";
              }
            ];
          }
        ];
        }
        {
          NixOS = [
          {
            "NixOS Discourse" = [
              {
                abbr = "ND";
                href = "https://discourse.nixos.org";
                icon = "https://discourse.nixos.org/uploads/default/original/2X/c/cb4fe584627b37e7c1d5424e9cec0bb30fdb6c4d.png";
              }
            ];
          }
          {
            "Nixpkgs" = [
              {
                abbr = "NP";
                href = "https://github.com/NixOS/nixpkgs";
                icon = "https://avatars.githubusercontent.com/u/487568?s=48&v=4";
              }
            ];
          }
          {
            "NixOS Search" = [
              {
                abbr = "NS";
                href = "https://search.nixos.org";
                icon = "https://search.nixos.org/images/nix-logo.png";
              }
            ];
          }
          {
            "Home Manager" = [
              {
                abbr = "HM";
                href = "https://nix-community.github.io/home-manager/options.xhtml";
                icon = "https://avatars.githubusercontent.com/u/33221035?s=200&v=4";
              }
            ];
          }
          {
            "NixOS Wiki" = [
              {
                abbr = "NW";
                href = "https://wiki.nixos.org";
                icon = "https://wiki.nixos.org/nixos.png";
              }
            ];
          }
        ];
        }
        {
          Social = [
          {
            Mastodon = [
              {
                abbr = "MD";
                href = "https://fosstodon.org/deck/@wimpy";
                icon = "mastodon.png";
              }
            ];
          }
          {
            Bluesky = [
              {
                abbr = "BS";
                href = "https://bsky.app/notifications";
                icon = "https://bsky.app/static/favicon-32x32.png";
              }
            ];
          }
          {
            Instagram = [
              {
                abbr = "IG";
                href = "https://www.instagram.com/";
                icon = "instagram.png";
              }
            ];
          }
          {
            X = [
              {
                abbr = "X";
                href = "https://x.com/flexiondotorg";
                icon = "x-light.png";
              }
            ];
          }
          {
            LinkedIn = [
              {
                abbr = "LI";
                href = "https://www.linkedin.com/in/martinwimpress/";
                icon = "linkedin.png";
              }
            ];
          }
        ];
        }
        {
          Shopping = [
          {
            Amazon = [
              {
                abbr = "AZ";
                href = "https://www.amazon.co.uk/";
                icon = "amazon-light.png";
              }
            ];
          }
          {
            eBay = [
              {
                abbr = "EB";
                href = "https://www.ebay.co.uk";
                icon = "ebay.png";
              }
            ];
          }
          {
            Ocado = [
              {
                abbr = "OC";
                href = "https://www.ocado.com/";
                icon = "https://www.ocado.com/webshop/static/images/7.4.99/favicon.png";
              }
            ];
          }
          {
            Tesco = [
              {
                abbr = "TS";
                href = "https://www.tesco.com/groceries";
                icon = "https://webautomation.io/static/images/domain_images/tescofav_2vycyUg.png";
              }
            ];
          }
          {
            Scan = [
              {
                abbr = "SC";
                href = "https://scan.co.uk";
                icon = "https://scan.co.uk/content/images/logo-192x192.png";
              }
            ];
          }
        ];
        }
        {
          Productivity = [
          {
            ChatGPT = [
              {
                abbr = "AI";
                href = "https://chatgpt.com/";
                icon = "https://cdn.oaistatic.com/_next/static/media/favicon-32x32.630a2b99.png";
              }
            ];
          }
          {
            Calendar = [
              {
                abbr = "CA";
                href = "https://calendar.google.com";
                icon = "https://ssl.gstatic.com/calendar/images/dynamiclogo_2020q4/calendar_31_2x.png";
              }
            ];
          }
          {
            Gmail = [
              {
                abbr = "GM";
                href = "https://mail.google.com";
                icon = "gmail.png";
              }
            ];
          }
          {
            Notion = [
              {
                abbr = "NT";
                href = "https://notion.so";
                icon = "notion.png";
              }
            ];
          }
        ];
        }
      ];
      services = [
        {
        Syncthing = [
          {
            "Revan" = {
              description = "Server: Home";
              icon = "syncthing.png";
              href = "https://revan.drongo-gamma.ts.net/syncthing/";
              siteMonitor = "https://revan.drongo-gamma.ts.net/syncthing/";
              widget = {
                type = "customapi";
                url = "https://revan.drongo-gamma.ts.net/syncthing/rest/svc/report";
                headers = {
                  X-API-Key = "{{HOMEPAGE_VAR_REVAN_SYNCTHING_API_KEY}}";
                };
                mappings = [
                  {
                    field = "numDevices";
                    label = "Devices";
                    format = "number";
                  }
                  {
                    field = "numFolders";
                    label = "Folders";
                    format = "number";
                  }
                  {
                    field = "totFiles";
                    label = "Files";
                    format = "number";
                  }
                  {
                    field = "totMiB";
                    label = "Stored (MB)";
                    format = "number";
                  }
                ];
              };
            };
          }
          {
            "Vader" = {
              description = "Workstation: Home";
              icon = "syncthing.png";
              href = "https://vader.drongo-gamma.ts.net/syncthing/";
              siteMonitor = "https://vader.drongo-gamma.ts.net/syncthing/";
              widget = {
                type = "customapi";
                url = "https://vader.drongo-gamma.ts.net/syncthing/rest/svc/report";
                headers = {
                  X-API-Key = "{{HOMEPAGE_VAR_VADER_SYNCTHING_API_KEY}}";
                };
                mappings = [
                  {
                    field = "numDevices";
                    label = "Devices";
                    format = "number";
                  }
                  {
                    field = "numFolders";
                    label = "Folders";
                    format = "number";
                  }
                  {
                    field = "totFiles";
                    label = "Files";
                    format = "number";
                  }
                  {
                    field = "totMiB";
                    label = "Stored (MB)";
                    format = "number";
                  }
                ];
              };
            };
          }
          {
            "Phasma" = {
              description = "Workstation: Office";
              icon = "syncthing.png";
              href = "https://phasma.drongo-gamma.ts.net/syncthing/";
              siteMonitor = "https://phasma.drongo-gamma.ts.net/syncthing/";
              widget = {
                type = "customapi";
                url = "https://phasma.drongo-gamma.ts.net/syncthing/rest/svc/report";
                headers = {
                  X-API-Key = "{{HOMEPAGE_VAR_PHASMA_SYNCTHING_API_KEY}}";
                };
                mappings = [
                  {
                    field = "numDevices";
                    label = "Devices";
                    format = "number";
                  }
                  {
                    field = "numFolders";
                    label = "Folders";
                    format = "number";
                  }
                  {
                    field = "totFiles";
                    label = "Files";
                    format = "number";
                  }
                  {
                    field = "totMiB";
                    label = "Stored (MB)";
                    format = "number";
                  }
                ];
              };
            };
          }
          {
            "Sidious" = {
              description = "Laptop: Thinkpad P1";
              icon = "syncthing.png";
              href = "https://sidious.drongo-gamma.ts.net/syncthing/";
              siteMonitor = "https://sidious.drongo-gamma.ts.net/syncthing/";
              widget = {
                type = "customapi";
                url = "https://sidious.drongo-gamma.ts.net/syncthing/rest/svc/report";
                headers = {
                  X-API-Key = "{{HOMEPAGE_VAR_SIDIOUS_SYNCTHING_API_KEY}}";
                };
                mappings = [
                  {
                    field = "numDevices";
                    label = "Devices";
                    format = "number";
                  }
                  {
                    field = "numFolders";
                    label = "Folders";
                    format = "number";
                  }
                  {
                    field = "totFiles";
                    label = "Files";
                    format = "number";
                  }
                  {
                    field = "totMiB";
                    label = "Stored (MB)";
                    format = "number";
                  }
                ];
              };
            };
          }
          {
            "Tanis" = {
              description = "Laptop: Thinkpad Z13";
              icon = "syncthing.png";
              href = "https://tanis.drongo-gamma.ts.net/syncthing/";
              siteMonitor = "https://tanis.drongo-gamma.ts.net/syncthing/";
              widget = {
                type = "customapi";
                url = "https://tanis.drongo-gamma.ts.net/syncthing/rest/svc/report";
                headers = {
                  X-API-Key = "{{HOMEPAGE_VAR_TANIS_SYNCTHING_API_KEY}}";
                };
                mappings = [
                  {
                    field = "numDevices";
                    label = "Devices";
                    format = "number";
                  }
                  {
                    field = "numFolders";
                    label = "Folders";
                    format = "number";
                  }
                  {
                    field = "totFiles";
                    label = "Files";
                    format = "number";
                  }
                  {
                    field = "totMiB";
                    label = "Stored (MB)";
                    format = "number";
                  }
                ];
              };
            };
          }
        ];
        }
        {
        Tailnet = [
          {
            "Revan" = {
              description = "Server: Home";
              icon = "tailscale.png";
              href = "https://revan.drongo-gamma.ts.net";
              widget = {
                type = "tailscale";
                deviceid = "{{HOMEPAGE_VAR_REVAN_TAILSCALE_DEVICEID}}";
                key = "{{HOMEPAGE_VAR_TAILSCALE_API_KEY}}";
              };
            };
          }
          {
            "Vader" = {
              description = "Workstation: Home";
              icon = "tailscale.png";
              href = "https://vader.drongo-gamma.ts.net";
              widget = {
                type = "tailscale";
                deviceid = "{{HOMEPAGE_VAR_VADER_TAILSCALE_DEVICEID}}";
                key = "{{HOMEPAGE_VAR_TAILSCALE_API_KEY}}";
              };
            };
          }
          {
            "Phasma" = {
              description = "Workstation: Office";
              icon = "tailscale.png";
              href = "https://phasma.drongo-gamma.ts.net";
              widget = {
                type = "tailscale";
                deviceid = "{{HOMEPAGE_VAR_PHASMA_TAILSCALE_DEVICEID}}";
                key = "{{HOMEPAGE_VAR_TAILSCALE_API_KEY}}";
              };
            };
          }
          {
            "Front Room" = {
              description = "AppleTV: Front Room";
              icon = "tailscale.png";
              href = "https://login.tailscale.com/admin/machines";
              widget = {
                type = "tailscale";
                deviceid = "{{HOMEPAGE_VAR_FRONTROOM_TAILSCALE_DEVICEID}}";
                key = "{{HOMEPAGE_VAR_TAILSCALE_API_KEY}}";
              };
            };
          }
          {
            "Bed Room" = {
              description = "AppleTV: Bed Room";
              icon = "tailscale.png";
              href = "https://login.tailscale.com/admin/machines";
              widget = {
                type = "tailscale";
                deviceid = "{{HOMEPAGE_VAR_BEDROOM_TAILSCALE_DEVICEID}}";
                key = "{{HOMEPAGE_VAR_TAILSCALE_API_KEY}}";
              };
            };
          }
        ];
        }
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
              siteMonitor = "https://192.168.2.250";
            };
          }
          {
            "Grandstream HT801" = {
              description = "VoIP: Home";
              icon = "voip-info.png";
              href = "http://192.168.2.58";
              siteMonitor = "http://192.168.2.58";
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
          image = "https://raw.githubusercontent.com/wimpysworld/nix-config/main/nixos/_mixins/configs/backgrounds/DeterminateColorway-2560x1440.png";
          blur = "sm";       # sm, md, xl... see https://tailwindcss.com/docs/backdrop-blur
          saturate = "75";   # 0, 50, 100... see https://tailwindcss.com/docs/backdrop-saturate
          brightness = "75"; # 0, 50, 75... see https://tailwindcss.com/docs/backdrop-brightness
          opacity = "100";   # 0-100
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
