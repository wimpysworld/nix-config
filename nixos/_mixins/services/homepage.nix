{ desktop, hostname, ... }:
let
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
in
{
  services = {
    homepage-dashboard = {
      enable = isInstall;
      bookmarks = [
        {
        Links = [
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
            "NixOS Wiki" = [
              {
                abbr = "NW";
                href = "https://wiki.nixos.org";
                icon = "https://wiki.nixos.org/nixos.png";
              }
            ];
          }
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
            Scan = [
              {
                abbr = "SC";
                href = "https://scan.co.uk";
                icon = "https://scan.co.uk/content/images/logo-192x192.png";
              }
            ];
          }
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
          "Hardware" = [
            {
              "Scrutiny" = {
                description = "Scrutiny: ${hostname}";
                href = "http://${hostname}.drongo-gamma.ts.net:8080";
              };
            }
          ];
        }
        {
          "Services" = [
            {
              "Syncthing" = {
                description = "Syncthing: ${hostname}";
                href = "http://${hostname}.drongo-gamma.ts.net:8384";
              };
            }
          ];
        }
      ];
      settings = {
        background = "https://raw.githubusercontent.com/wimpysworld/nix-config/main/nixos/_mixins/configs/backgrounds/DeterminateColorway-2560x1440.png";
        color = "zinc";
        favicon = "https://wimpysworld.com/favicon.ico";
        hideVersion = true;
        layout = {
          Links = {
            style = "row";
            columns = 4;
          };
        };
        showStats = true;
        title = "Wimpy's Dashboard";
      };
      widgets = [
        {
          search = {
            provider = "custom";
            target = "_blank";
            url = "https://kagi.com/search?q=";
          };
        }
        {
          resources = {
            label = "system";
            cpu = true;
            memory = true;
          };
        }
        {
          resources = {
            label = "storage";
            disk = [ "/" "/home"];
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
    caddy = {
      enable = true;
      virtualHosts."localhost" = {
        extraConfig = ''
          reverse_proxy http://127.0.0.1:8082
        '';
        serverAliases = [ "${hostname}.drongo-gamma.ts.net" ];
      };
    };
    # Enable caddy to acquire certificates from the tailscale daemon
    # - https://tailscale.com/blog/caddy
    tailscale.permitCertUid = "caddy";
  };
}
