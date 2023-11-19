{ pkgs, ... }:
let
    homepage-bookmarks = pkgs.writeTextFile {
    name = "bookmarks.yaml";
    executable = false;
    destination = "/var/lib/private/homepage-dashboard/bookmarks.yaml";
    text = ''
---
# For configuration options and examples, please see:
# https://gethomepage.dev/en/configs/bookmarks

- Developer:
    - Github:
        - abbr: GH
          href: https://github.com/

- Social:
    - Twitter:
        - abbr: X
          href: https://twitter.com/

- Entertainment:
    - YouTube:
        - abbr: YT
          href: https://youtube.com/
    '';
  };
in
{
  services.homepage-dashboard = {
    enable = true;
    package = pkgs.homepage-dashboard;
    openFirewall = true;
  };
  
  environment.systemPackages = [ homepage-bookmarks ];
}
