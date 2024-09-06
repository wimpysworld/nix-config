{ config, ... }:
let
  pngFiles = builtins.filter (file: builtins.match ".*\\.png" file != null) (
    builtins.attrNames (builtins.readDir ./.)
  );
in
{
  # Copy .png files in the current directory to the wlogout configuration directory
  home.file = builtins.listToAttrs (
    builtins.map (pngFile: {
      name = "${config.xdg.configHome}/wlogout/${pngFile}";
      value = {
        source = ./. + "/${pngFile}";
      };
    }) pngFiles
  );

  programs = {
    wlogout = {
      enable = true;
      layout = [
        {
          label = "lock";
          action = "hypr-session lock";
          text = "  Lock  ";
          keybind = "l";
          height = 0.5;
        }
        {
          label = "logout";
          action = "hypr-session logout";
          text = " Logout ";
          keybind = "e";
          height = 0.5;
        }
        {
          label = "suspend";
          action = "systemctl suspend";
          text = "Suspend";
          keybind = "u";
          height = 0.5;
        }
        {
          label = "reboot";
          action = "hypr-session reboot";
          text = " Reboot ";
          keybind = "r";
          height = 0.5;
        }
        {
          label = "shutdown";
          action = "hypr-session shutdown";
          text = "Shutdown";
          keybind = "s";
          height = 0.5;
        }
      ];
      style = ''
        window {
            font-family: FiraCode Nerd Font Mono, monospace;
            font-size: 18pt;
            color: #cdd6f4; /* text */
            background-color: rgba(30, 30, 46, 0.5);
        }

        button {
            background-repeat: no-repeat;
            background-position: center;
            background-size: 50%;
            border: none;
            background-color: rgba(30, 30, 46, 0);
            margin: 100px 5px 100px 5px;
            transition: box-shadow 0.2s ease-in-out, background-color 0.2s ease-in-out;
        }
        button:hover {
            background-color: rgba(49, 50, 68, 0.1);
        }
        button:focus {
            background-color: #89b4fa; /* accent (blue) */
            color: #11111b; /* crust */
        }

        #lock {
          background-image: image(url("./lock.png"));
        }
        #lock:focus {
          background-image: image(url("./lock-hover.png"));
        }

        #clear {
          background-image: image(url("./clear.png"));
        }
        #clear:focus {
          background-image: image(url("./clear-hover.png"));
        }

        #logout {
          background-image: image(url("./logout.png"));
        }
        #logout:focus {
          background-image: image(url("./logout-hover.png"));
        }

        #reboot {
          background-image: image(url("./reboot.png"));
        }
        #reboot:focus {
          background-image: image(url("./reboot-hover.png"));
        }

        #suspend {
          background-image: image(url("./suspend.png"));
        }
        #suspend:focus {
          background-image: image(url("./suspend-hover.png"));
        }

        #shutdown {
          background-image: image(url("./shutdown.png"));
        }
        #shutdown:focus {
          background-image: image(url("./shutdown-hover.png"));
        }
      '';
    };
  };
}
