{
  config,
  hostname,
  lib,
  pkgs,
  ...
}:
let
  installOn = [
    "phasma"
    "tanis"
    "revan"
    "sidious"
    "vader"
  ];
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  services = {
    homepage-dashboard = {
      enable = true;
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
