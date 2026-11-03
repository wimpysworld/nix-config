{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (config.noughty.network) tailNet;
  tailnetHost = "${host.name}.${tailNet}";
  homepagePort = 8082;

  registry = builtins.fromTOML (builtins.readFile ../../../../lib/registry-systems.toml);
  syncDefs = import ../../../../home-manager/_mixins/filesync/syncthing-devices.nix;

  hostsWithTag =
    tag: lib.attrNames (lib.filterAttrs (_name: entry: lib.elem tag (entry.tags or [ ])) registry);

  isNixOSTailnetHost =
    _name: entry:
    let
      tags = entry.tags or [ ];
    in
    lib.hasSuffix "-linux" entry.platform
    && (entry.kind == "computer" || entry.kind == "server")
    && !(lib.elem "iso" tags)
    && !(lib.elem "steamdeck" tags)
    && !(lib.elem "wsl" tags)
    && !(lib.elem "openstack" tags);

  tailnetHosts = lib.attrNames (lib.filterAttrs isNixOSTailnetHost registry);
  syncthingHosts = lib.filter (node: builtins.hasAttr node syncDefs.devices) tailnetHosts;
  roamgateHosts = hostsWithTag "roamgate";
  reframeHosts = hostsWithTag "reframe";
  remoteInferenceHosts = lib.filter (name: name != host.name) (hostsWithTag "inference");
in
lib.mkIf (noughtyLib.hostHasTag "homepage") {
  environment.shellAliases = {
    homepage-log = "journalctl _SYSTEMD_UNIT=homepage-dashboard.service";
  };

  sops = {
    secrets = {
      HOMEPAGE_VAR_SILO_API_KEY = {
        sopsFile = ../../../../secrets/homepage.yaml;
        owner = "root";
        group = "root";
        mode = "0400";
      };
      HOMEPAGE_VAR_SYNCTHING_API_KEY = {
        sopsFile = ../../../../secrets/syncthing.yaml;
        key = "apikey";
        owner = "root";
        group = "root";
        mode = "0400";
      };
      HOMEPAGE_VAR_CLOUDFLARE_ACCOUNT_ID = {
        sopsFile = ../../../../secrets/cloudflare.yaml;
        key = "CLOUDFLARE_ACCOUNT_ID";
        owner = "root";
        group = "root";
        mode = "0400";
      };
      HOMEPAGE_VAR_CLOUDFLARE_API_TOKEN = {
        sopsFile = ../../../../secrets/cloudflare.yaml;
        key = "CLOUDFLARE_API_TOKEN";
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    templates."homepage.env" = {
      content = ''
        HOMEPAGE_VAR_SILO_API_KEY=${config.sops.placeholder.HOMEPAGE_VAR_SILO_API_KEY}
        HOMEPAGE_VAR_SYNCTHING_API_KEY=${config.sops.placeholder.HOMEPAGE_VAR_SYNCTHING_API_KEY}
        HOMEPAGE_VAR_CLOUDFLARE_ACCOUNT_ID=${config.sops.placeholder.HOMEPAGE_VAR_CLOUDFLARE_ACCOUNT_ID}
        HOMEPAGE_VAR_CLOUDFLARE_API_TOKEN=${config.sops.placeholder.HOMEPAGE_VAR_CLOUDFLARE_API_TOKEN}
      '';
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "homepage-dashboard.service" ];
    };
  };

  services = {
    caddy.virtualHosts."${tailnetHost}".extraConfig =
      lib.mkIf (config.services.caddy.enable && config.services.tailscale.enable)
        ''
          @homepage not path /syncthing /syncthing/* /socket /uploads /uploads/*
          handle @homepage {
            reverse_proxy 127.0.0.1:${toString homepagePort}
          }
        '';

    homepage-dashboard = {
      enable = true;
      listenPort = homepagePort;
      openFirewall = false;
      environmentFiles = [ config.sops.templates."homepage.env".path ];
      allowedHosts = lib.concatStringsSep "," [
        "localhost:${toString homepagePort}"
        "127.0.0.1:${toString homepagePort}"
        host.name
        "${host.name}:${toString homepagePort}"
        tailnetHost
        "${tailnetHost}:${toString homepagePort}"
      ];

      settings = {
        title = "Wimpy's World";
        description = "Infrastructure, Media & Tailnet Dashboard";
        theme = "dark";
        color = "slate";
        headerStyle = "clean";
        statusStyle = "dot";
        hideVersion = true;
        layout = {
          "Media & Notes (Revan)" = {
            style = "row";
            columns = 4;
          };
          "AI & Agents" = {
            style = "row";
            columns = 4;
          };
          "Monitoring & Infrastructure" = {
            style = "row";
            columns = 3;
          };
          "Websites" = {
            style = "row";
            columns = 3;
          };
          "Social & Streaming" = {
            style = "row";
            columns = 3;
          };
          "Tailnet Fleet & Remote Access" = {
            style = "row";
            columns = 3;
          };
          "Syncthing Fleet" = {
            style = "row";
            columns = 4;
          };
        };
      };

      widgets = [
        {
          resources = {
            label = "Revan";
            cpu = true;
            memory = true;
            cputemp = true;
            uptime = true;
            units = "metric";
          };
        }
        {
          resources = {
            label = "Storage";
            expanded = true;
            disk = [
              "/"
              "/srv/pool"
              "/mnt/snapshot"
            ];
          };
        }
        {
          search = {
            provider = "custom";
            url = "https://kagi.com/search?q=";
            suggestionUrl = "https://kagi.com/api/autosuggest?q=";
            showSearchSuggestions = true;
            target = "_blank";
          };
        }
      ];

      services = [
        {
          "Media & Notes (Revan)" = [
            {
              "Silo" = {
                icon = "jellyfin.svg";
                href = "http://${tailnetHost}:8090";
                description = "Silo media server on revan";
                siteMonitor = "http://127.0.0.1:8090/api/v1/health";
                widget = {
                  type = "jellyfin";
                  url = "http://127.0.0.1:8096";
                  key = "{{HOMEPAGE_VAR_SILO_API_KEY}}";
                  version = 2;
                  enableBlocks = true;
                  enableNowPlaying = true;
                  enableUser = true;
                  showEpisodeNumber = true;
                  fields = [
                    "movies"
                    "series"
                    "episodes"
                  ];
                };
              };
            }
            {
              "Silo (Jellyfin API)" = {
                icon = "jellyfin.svg";
                href = "http://${tailnetHost}:8096";
                description = "Jellyfin-compatible endpoint on revan";
                siteMonitor = "http://127.0.0.1:8096/System/Info/Public";
                widget = {
                  type = "customapi";
                  url = "http://127.0.0.1:8096/System/Info/Public";
                  mappings = [
                    {
                      field = "ServerName";
                      label = "Server";
                      format = "text";
                    }
                    {
                      field = "Version";
                      label = "Compat";
                      format = "text";
                    }
                  ];
                };
              };
            }
            {
              "Silo (Audiobookshelf API)" = {
                icon = "audiobookshelf.svg";
                href = "http://${tailnetHost}:13378";
                description = "Audiobookshelf-compatible endpoint on revan";
                siteMonitor = "http://127.0.0.1:13378/ping";
                widget = {
                  type = "customapi";
                  url = "http://127.0.0.1:13378/status";
                  mappings = [
                    {
                      field = "app";
                      label = "Surface";
                      format = "text";
                    }
                    {
                      field = "serverVersion";
                      label = "Compat";
                      format = "text";
                    }
                  ];
                };
              };
            }
            {
              "Weave Notes" = {
                icon = "mdi-language-markdown";
                href = "https://notes.wimpys.world";
                description = "Zettelkasten notebook web interface";
                siteMonitor = "http://127.0.0.1:8000";
                widget = {
                  type = "cloudflared";
                  accountid = "{{HOMEPAGE_VAR_CLOUDFLARE_ACCOUNT_ID}}";
                  tunnelid = "49acf03b-9085-4d78-a60c-154b54d02406";
                  key = "{{HOMEPAGE_VAR_CLOUDFLARE_API_TOKEN}}";
                };
              };
            }
            {
              "Owncast (Test)" = {
                icon = "owncast.svg";
                href = "http://${tailnetHost}:8383";
                description = "Staging Owncast instance on revan";
                siteMonitor = "http://127.0.0.1:8383/api/status";
                widget = {
                  type = "customapi";
                  url = "http://127.0.0.1:8383/api/status";
                  mappings = [
                    {
                      field = "online";
                      label = "Stream";
                      format = "text";
                      remap = [
                        {
                          value = true;
                          to = "Live";
                        }
                        {
                          value = false;
                          to = "Offline";
                        }
                      ];
                    }
                    {
                      field = "versionNumber";
                      label = "Version";
                      format = "text";
                    }
                  ];
                };
              };
            }
          ];
        }
        {
          "AI & Agents" = [
            {
              "LibreChat" = {
                icon = "librechat.svg";
                href = "https://librechat.wimpys.world";
                description = "Self-hosted AI chat platform";
                siteMonitor = "http://127.0.0.1:3080";
                widget = {
                  type = "cloudflared";
                  accountid = "{{HOMEPAGE_VAR_CLOUDFLARE_ACCOUNT_ID}}";
                  tunnelid = "1efaa599-51f7-4825-b2fa-3df1233883e6";
                  key = "{{HOMEPAGE_VAR_CLOUDFLARE_API_TOKEN}}";
                };
              };
            }
            {
              "llama-swap (revan)" = {
                icon = "ollama.svg";
                href = "http://${tailnetHost}:8080";
                description = "Local LLM router and embeddings on revan";
                siteMonitor = "http://127.0.0.1:8080/health";
                widget = {
                  type = "customapi";
                  url = "http://127.0.0.1:8080/running";
                  mappings = [
                    {
                      field = "running";
                      label = "Loaded Models";
                      format = "size";
                    }
                  ];
                };
              };
            }
          ]
          ++ (map (node: {
            "llama-swap (${node})" = {
              icon = "ollama.svg";
              href = "http://${node}.${tailNet}:8080";
              description = "LLM inference router on ${node}";
              ping = "${node}.${tailNet}";
            };
          }) remoteInferenceHosts)
          ++ (map (node: {
            "Roamgate (${node})" = {
              icon = "terminal.svg";
              href = "https://${node}.${tailNet}:10000/";
              description = "Herdr Roamgate web terminal on ${node}";
              ping = "${node}.${tailNet}";
            };
          }) roamgateHosts);
        }
        {
          "Monitoring & Infrastructure" = [
            {
              "Gatus" = {
                icon = "gatus.svg";
                href = "https://gatus.wimpys.world";
                description = "Wimpy's World uptime and certificate status";
                siteMonitor = "http://127.0.0.1:8741";
                widget = {
                  type = "gatus";
                  url = "http://127.0.0.1:8741";
                };
              };
            }
            {
              "GoAccess Analytics" = {
                icon = "goaccess.svg";
                href = "https://goaccess.wimpys.world";
                description = "Real-time web log analytics on malak";
                ping = "malak.${tailNet}";
              };
            }
            {
              "Soju IRC Bouncer" = {
                icon = "mdi-forum-outline";
                href = "https://${tailnetHost}";
                description = "Multi-network IRC bouncer on revan (:6667)";
                ping = "127.0.0.1";
              };
            }
          ];
        }
        {
          "Websites" = [
            {
              "Wimpy's World" = {
                icon = "mdi-web";
                href = "https://wimpysworld.com";
                description = "Personal blog and notes";
                siteMonitor = "https://wimpysworld.com";
                widget = {
                  type = "customapi";
                  url = "https://wimpysworld.com/index.json";
                  refreshInterval = 3600000;
                  mappings = [
                    {
                      label = "Posts";
                      format = "size";
                    }
                    {
                      field = {
                        "0" = "title";
                      };
                      label = "Latest";
                      format = "text";
                    }
                  ];
                };
              };
            }
            {
              "Linux Matters" = {
                icon = "mdi-podcast";
                href = "https://linuxmatters.sh";
                description = "Linux Matters podcast website";
                siteMonitor = "https://linuxmatters.sh";
                widget = {
                  type = "customapi";
                  url = "https://itunes.apple.com/lookup?id=1682797246";
                  refreshInterval = 3600000;
                  mappings = [
                    {
                      field = {
                        results = {
                          "0" = "trackCount";
                        };
                      };
                      label = "Episodes";
                      format = "number";
                    }
                    {
                      field = {
                        results = {
                          "0" = "releaseDate";
                        };
                      };
                      label = "Latest";
                      format = "date";
                      dateStyle = "medium";
                    }
                    {
                      field = {
                        results = {
                          "0" = "trackTimeMillis";
                        };
                      };
                      label = "Runtime";
                      format = "duration";
                    }
                  ];
                };
              };
            }
            {
              "Wimpy's Links" = {
                icon = "mdi-link-variant";
                href = "https://wimpysworld.link";
                description = "Social and project links";
                siteMonitor = "https://wimpysworld.link";
              };
            }
          ];
        }
        {
          "Social & Streaming" = [
            {
              "The Cauldron (Matrix)" = {
                icon = "matrix.svg";
                href = "https://matrix.wimpys.world";
                description = "Tuwunel Matrix homeserver on malak";
                siteMonitor = "https://matrix.wimpys.world/_matrix/client/versions";
                widget = {
                  type = "customapi";
                  url = "https://matrix.wimpys.world/_matrix/client/versions";
                  mappings = [
                    {
                      field = {
                        "net.zemos.msc4383.server" = "name";
                      };
                      label = "Server";
                      format = "text";
                    }
                    {
                      field = {
                        "net.zemos.msc4383.server" = "version";
                      };
                      label = "Version";
                      format = "text";
                    }
                    {
                      field = "versions";
                      label = "Specs";
                      format = "size";
                    }
                  ];
                };
              };
            }
            {
              "GoToSocial" = {
                icon = "gotosocial.svg";
                href = "https://wimpysworld.social";
                description = "Fediverse instance on malak";
                siteMonitor = "https://ip.wimpysworld.social";
                widget = {
                  type = "customapi";
                  url = "https://wimpysworld.social/api/v1/instance";
                  headers = {
                    "User-Agent" = "Homepage";
                  };
                  mappings = [
                    {
                      field = "version";
                      label = "Version";
                      format = "text";
                    }
                    {
                      field = {
                        stats = "user_count";
                      };
                      label = "Users";
                      format = "number";
                    }
                    {
                      field = {
                        stats = "status_count";
                      };
                      label = "Statuses";
                      format = "number";
                    }
                    {
                      field = {
                        stats = "domain_count";
                      };
                      label = "Peers";
                      format = "number";
                    }
                  ];
                };
              };
            }
            {
              "Owncast Live" = {
                icon = "owncast.svg";
                href = "https://wimpysworld.live";
                description = "Production live streaming server on malak";
                siteMonitor = "https://wimpysworld.live/api/status";
                widget = {
                  type = "customapi";
                  url = "https://wimpysworld.live/api/status";
                  mappings = [
                    {
                      field = "online";
                      label = "Stream";
                      format = "text";
                      remap = [
                        {
                          value = true;
                          to = "Live";
                        }
                        {
                          value = false;
                          to = "Offline";
                        }
                      ];
                    }
                    {
                      field = "versionNumber";
                      label = "Version";
                      format = "text";
                    }
                  ];
                };
              };
            }
          ];
        }
        {
          "Tailnet Fleet & Remote Access" =
            (map (node: {
              "ReFrame noVNC (${node})" = {
                icon = "novnc.svg";
                href = "https://${node}.${tailNet}/novnc";
                description = "Browser remote desktop on ${node}";
                ping = "${node}.${tailNet}";
              };
            }) reframeHosts)
            ++ [
              {
                "Flood / Transmission (skrye)" = {
                  icon = "flood.svg";
                  href = "http://skrye.${tailNet}:9091";
                  description = "Flood web UI for Transmission on skrye";
                  ping = "skrye.${tailNet}";
                  widget = {
                    type = "transmission";
                    url = "http://skrye.${tailNet}:9091";
                  };
                };
              }
            ];
        }
        {
          "Syncthing Fleet" = map (node: {
            "Syncthing (${node})" = {
              icon = "syncthing.svg";
              href = "https://${node}.${tailNet}/syncthing/";
              description = "Syncthing web GUI on ${node}";
              ping = "${node}.${tailNet}";
            }
            // lib.optionalAttrs (node == host.name) {
              widget = {
                type = "customapi";
                url = "http://127.0.0.1:8384/rest/db/completion";
                headers = {
                  "X-API-Key" = "{{HOMEPAGE_VAR_SYNCTHING_API_KEY}}";
                };
                mappings = [
                  {
                    field = "completion";
                    label = "Completion";
                    format = "percent";
                  }
                  {
                    field = "globalItems";
                    label = "Items";
                    format = "number";
                  }
                  {
                    field = "globalBytes";
                    label = "Size";
                    format = "bytes";
                  }
                  {
                    field = "needItems";
                    label = "Pending";
                    format = "number";
                  }
                ];
              };
            };
          }) syncthingHosts;
        }
      ];
    };
  };

  systemd.services.homepage-dashboard = {
    after = [ "sops-nix.service" ];
    wants = [ "sops-nix.service" ];
    environment = {
      HOMEPAGE_PROXY_DISABLE_IPV6 = "true";
    };
    unitConfig = {
      RequiresMountsFor = [
        "/srv/pool"
        "/mnt/snapshot"
      ];
    };
  };
}
