{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) types;

  cfg = config.programs.vtm;

  literalType = types.submodule {
    options = {
      _type = lib.mkOption {
        type = types.enum [ "vtmLiteral" ];
        default = "vtmLiteral";
        internal = true;
      };

      text = lib.mkOption {
        type = types.str;
        description = "Raw DynamicXML literal rendered without quotes.";
      };
    };
  };

  dynamicStringType = types.oneOf [
    types.str
    literalType
  ];

  nullOrString = types.nullOr dynamicStringType;
  dynamicValueType = types.oneOf [
    types.int
    dynamicStringType
  ];
  nullOrDynamicValue = types.nullOr dynamicValueType;
  nullOrBoolToken = types.nullOr (
    types.oneOf [
      types.bool
      literalType
    ]
  );
  colorTokenType = types.oneOf [
    types.str
    literalType
  ];

  nullOrColorToken = types.nullOr colorTokenType;

  colorStyleType = types.submodule {
    options = {
      foreground = lib.mkOption {
        type = nullOrColorToken;
        default = null;
        description = "Foreground colour token rendered as raw DynamicXML.";
      };

      background = lib.mkOption {
        type = nullOrColorToken;
        default = null;
        description = "Background colour token rendered as raw DynamicXML.";
      };

      alpha = lib.mkOption {
        type = nullOrDynamicValue;
        default = null;
      };

      text = lib.mkOption {
        type = nullOrColorToken;
        default = null;
        description = "SGR text colour or style token rendered as the DynamicXML txt attribute.";
      };

      fx = lib.mkOption {
        type = types.nullOr (
          types.enum [
            "xlight"
            "color"
            "invert"
            "reverse"
          ]
        );
        default = null;
      };

      inverse = lib.mkOption {
        type = nullOrBoolToken;
        default = null;
      };

      italic = lib.mkOption {
        type = nullOrBoolToken;
        default = null;
      };

      bold = lib.mkOption {
        type = nullOrBoolToken;
        default = null;
      };

      underline = lib.mkOption {
        type = nullOrBoolToken;
        default = null;
      };

      overline = lib.mkOption {
        type = nullOrBoolToken;
        default = null;
      };

      blink = lib.mkOption {
        type = nullOrBoolToken;
        default = null;
      };
    };
  };

  terminalPaletteType = types.addCheck (types.listOf colorTokenType) (
    value: value == [ ] || builtins.length value == 16
  );

  mkColorStyleOption =
    description:
    lib.mkOption {
      type = colorStyleType;
      default = { };
      inherit description;
    };

  catppuccinVtm = import ../../../../lib/vtm-catppuccin-themes.nix { inherit lib; };
  catppuccinThemes = catppuccinVtm.themes;

  mkDefaults = lib.mapAttrsRecursive (_path: value: lib.mkDefault value);
  themeSettings = if cfg.theme == null then { } else mkDefaults cfg.themes.${cfg.theme};

  itemType = types.submodule {
    options = {
      id = lib.mkOption {
        type = nullOrString;
        default = null;
      };

      splitter = lib.mkOption {
        type = types.bool;
        default = false;
      };

      hidden = lib.mkOption {
        type = types.nullOr types.bool;
        default = null;
      };

      label = lib.mkOption {
        type = nullOrString;
        default = null;
      };

      tooltip = lib.mkOption {
        type = nullOrString;
        default = null;
      };

      title = lib.mkOption {
        type = nullOrString;
        default = null;
      };

      footer = lib.mkOption {
        type = nullOrString;
        default = null;
      };

      wincoor = lib.mkOption {
        type = nullOrString;
        default = null;
        example = "8,4";
      };

      winsize = lib.mkOption {
        type = nullOrString;
        default = null;
        example = "120,40";
      };

      winform = lib.mkOption {
        type = types.nullOr (
          types.enum [
            "normal"
            "maximized"
            "minimized"
          ]
        );
        default = null;
      };

      type = lib.mkOption {
        type = types.nullOr (
          types.enum [
            "vtty"
            "term"
            "dtvt"
            "dtty"
            "tile"
            "site"
          ]
        );
        default = null;
      };

      env = lib.mkOption {
        type = nullOrString;
        default = null;
        example = "EDITOR=nvim";
      };

      cwd = lib.mkOption {
        type = nullOrString;
        default = null;
      };

      cmd = lib.mkOption {
        type = nullOrString;
        default = null;
      };

      cfg = lib.mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Raw DynamicXML passed to DirectVT-aware child applications.";
      };

      config = lib.mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Raw nested <config> body for this taskbar item.";
      };
    };
  };

  autorunItemType = types.submodule {
    options = {
      id = lib.mkOption {
        type = nullOrString;
        default = null;
      };

      wincoor = lib.mkOption {
        type = nullOrString;
        default = null;
        example = "8,31";
      };

      winsize = lib.mkOption {
        type = nullOrString;
        default = null;
        example = "80,25";
      };

      winform = lib.mkOption {
        type = types.nullOr (types.enum [ "minimized" ]);
        default = null;
      };

      focused = lib.mkOption {
        type = types.bool;
        default = false;
      };
    };
  };

  rawSubtreeType =
    description:
    types.submodule {
      options = {
        source = lib.mkOption {
          type = nullOrString;
          default = null;
          description = "Optional DynamicXML value assigned to the element name. Wrap references with programs.vtm.literal.";
        };

        body = lib.mkOption {
          type = types.lines;
          default = "";
          inherit description;
        };
      };
    };

  indent = level: lib.concatStrings (lib.replicate level "    ");

  isLiteral = value: lib.isAttrs value && value ? _type && value._type == "vtmLiteral";

  escapeDynamicXmlString =
    value:
    builtins.replaceStrings
      [
        "\\"
        "\""
        "\n"
        "\t"
      ]
      [
        "\\\\"
        "\\\""
        "\\n"
        "\\t"
      ]
      value;

  renderValue =
    value:
    if isLiteral value then
      value.text
    else if lib.isBool value then
      lib.boolToString value
    else if lib.isInt value then
      toString value
    else
      "\"${escapeDynamicXmlString value}\"";

  renderLine =
    level: name: value:
    lib.optionalString (value != null) "${indent level}<${name}=${renderValue value}/>";

  nonEmpty = value: value != "";

  joinLines = lines: lib.concatStringsSep "\n" (lib.filter nonEmpty lines);

  renderElement =
    level: name: body:
    lib.optionalString (body != "") "${indent level}<${name}>\n${body}\n${indent level}</${name}>";

  renderAttribute =
    attr:
    let
      inherit (attr) name;
      inherit (attr) value;
      bareWhenTrue = attr.bareWhenTrue or false;
      renderer = attr.renderer or renderValue;
    in
    if value == null || (bareWhenTrue && value == false) then
      null
    else if bareWhenTrue && value == true then
      name
    else
      "${name}=${renderer value}";

  renderAttributes =
    attrs: lib.concatStringsSep " " (lib.filter (value: value != null) (map renderAttribute attrs));

  renderColorValue = value: if isLiteral value then value.text else value;

  renderColorElement =
    level: name: color:
    let
      attributes = renderAttributes [
        {
          name = "fgc";
          value = color.foreground;
          renderer = renderColorValue;
        }
        {
          name = "bgc";
          value = color.background;
          renderer = renderColorValue;
        }
        {
          name = "alpha";
          value = color.alpha;
        }
        {
          name = "txt";
          value = color.text;
          renderer = renderColorValue;
        }
        {
          name = "fx";
          value = color.fx;
        }
        {
          name = "inv";
          value = color.inverse;
        }
        {
          name = "itc";
          value = color.italic;
        }
        {
          name = "bld";
          value = color.bold;
        }
        {
          name = "und";
          value = color.underline;
        }
        {
          name = "ovr";
          value = color.overline;
        }
        {
          name = "blk";
          value = color.blink;
        }
      ];
    in
    lib.optionalString (attributes != "") "${indent level}<${name} ${attributes}/>";

  renderColorLine =
    level: name: value:
    lib.optionalString (value != null) "${indent level}<${name}=${renderColorValue value}/>";

  renderRawSubtree =
    level: name: subtree:
    let
      sourceText = lib.optionalString (subtree.source != null) "=${renderValue subtree.source}";
    in
    if subtree.body == "" && subtree.source == null then
      ""
    else if subtree.body == "" then
      "${indent level}<${name}${sourceText}/>"
    else
      "${indent level}<${name}${sourceText}>\n${subtree.body}\n${indent level}</${name}>";

  renderPreview =
    level: preview:
    let
      attributes = renderAttributes [
        {
          name = "enabled";
          value = preview.enabled;
        }
        {
          name = "size";
          value = preview.size;
        }
      ];
      attributeText = lib.optionalString (attributes != "") " ${attributes}";
      body = joinLines [
        (renderColorElement (level + 1) "color" preview.color)
        (renderLine (level + 1) "alpha" preview.alpha)
        (renderLine (level + 1) "timeout" preview.timeout)
        (renderLine (level + 1) "shadow" preview.shadow)
      ];
    in
    if body == "" && attributes == "" then
      ""
    else if body == "" then
      "${indent level}<preview${attributeText}/>"
    else
      "${indent level}<preview${attributeText}>\n${body}\n${indent level}</preview>";

  renderTaskbarItem =
    item:
    let
      attributes = renderAttributes [
        {
          name = "id";
          value = item.id;
        }
        {
          name = "splitter";
          value = item.splitter;
          bareWhenTrue = true;
        }
        {
          name = "hidden";
          value = item.hidden;
        }
        {
          name = "label";
          value = item.label;
        }
        {
          name = "tooltip";
          value = item.tooltip;
        }
        {
          name = "title";
          value = item.title;
        }
        {
          name = "footer";
          value = item.footer;
        }
        {
          name = "wincoor";
          value = item.wincoor;
        }
        {
          name = "winsize";
          value = item.winsize;
        }
        {
          name = "winform";
          value = item.winform;
        }
        {
          name = "type";
          value = item.type;
        }
        {
          name = "env";
          value = item.env;
        }
        {
          name = "cwd";
          value = item.cwd;
        }
        {
          name = "cmd";
          value = item.cmd;
        }
        {
          name = "cfg";
          value = item.cfg;
        }
      ];
      attributeText = lib.optionalString (attributes != "") " ${attributes}";
      configBody = lib.optionalString (
        item.config != null
      ) "${indent 4}<config>\n${item.config}\n${indent 4}</config>";
    in
    if item.config == null then
      "${indent 3}<item${attributeText}/>"
    else
      "${indent 3}<item${attributeText}>\n${configBody}\n${indent 3}</item>";

  renderAutorunItem =
    item:
    let
      attributes = renderAttributes [
        {
          name = "id";
          value = item.id;
        }
        {
          name = "wincoor";
          value = item.wincoor;
        }
        {
          name = "winsize";
          value = item.winsize;
        }
        {
          name = "winform";
          value = item.winform;
        }
        {
          name = "focused";
          value = item.focused;
          bareWhenTrue = true;
        }
      ];
      attributeText = lib.optionalString (attributes != "") " ${attributes}";
    in
    "${indent 4}<run${attributeText}/>";

  renderAutorun =
    autorun:
    let
      body = joinLines (
        lib.optional autorun.clearRuns "${indent 4}<run*/>" ++ map renderAutorunItem autorun.items
      );
    in
    renderElement 3 "autorun" body;

  renderTaskbarWidth =
    width:
    renderElement 3 "width" (joinLines [
      (renderLine 4 "folded" width.folded)
      (renderLine 4 "expanded" width.expanded)
    ]);

  renderTaskbar =
    taskbar:
    let
      attributes = renderAttributes [
        {
          name = "wide";
          value = taskbar.wide;
        }
        {
          name = "selected";
          value = taskbar.selected;
        }
      ];
      attributeText = lib.optionalString (attributes != "") " ${attributes}";
      colorsBody = renderElement 3 "colors" (joinLines [
        (renderColorElement 4 "bground" taskbar.colors.background)
        (renderColorElement 4 "focused" taskbar.colors.focused)
        (renderColorElement 4 "selected" taskbar.colors.selected)
        (renderColorElement 4 "active" taskbar.colors.active)
        (renderColorElement 4 "inactive" taskbar.colors.inactive)
      ]);
      body = joinLines (
        lib.optional taskbar.clearItems "${indent 3}<item*/>"
        ++ map renderTaskbarItem taskbar.items
        ++ [
          (renderAutorun taskbar.autorun)
          (renderTaskbarWidth taskbar.width)
          (renderLine 3 "timeout" taskbar.timeout)
          colorsBody
        ]
      );
    in
    if body == "" && attributes == "" then
      ""
    else if body == "" then
      "${indent 2}<taskbar${attributeText}/>"
    else
      "${indent 2}<taskbar${attributeText}>\n${body}\n${indent 2}</taskbar>";

  renderTerminalPalette =
    level: palette:
    joinLines (
      lib.imap0 (index: colour: renderColorLine level "color${toString index}" colour) palette
    );

  renderScrollbackReset =
    level: reset:
    let
      attributes = renderAttributes [
        {
          name = "onkey";
          value = reset.onKey;
        }
        {
          name = "onoutput";
          value = reset.onOutput;
        }
      ];
    in
    lib.optionalString (attributes != "") "${indent level}<reset ${attributes}/>";

  renderTerminalColors =
    level: colors:
    renderElement level "colors" (joinLines [
      (renderTerminalPalette (level + 1) colors.palette)
      (renderColorElement (level + 1) "default" colors.default)
      (renderColorElement (level + 1) "match" colors.match)
      (renderElement (level + 1) "selection" (joinLines [
        (renderColorElement (level + 2) "text" colors.selection.text)
        (renderColorElement (level + 2) "protected" colors.selection.protected)
        (renderColorElement (level + 2) "ansi" colors.selection.ansi)
        (renderColorElement (level + 2) "rich" colors.selection.rich)
        (renderColorElement (level + 2) "html" colors.selection.html)
        (renderColorElement (level + 2) "none" colors.selection.none)
      ]))
      (renderRawSubtree (level + 1) "names" colors.names)
    ]);

  renderTimings =
    timings:
    renderElement 1 "timings" (joinLines [
      (renderLine 2 "fps" timings.fps)
      (renderElement 2 "kinetic" (joinLines [
        (renderLine 3 "spd" timings.kinetic.speed)
        (renderLine 3 "pls" timings.kinetic.pulse)
        (renderLine 3 "ccl" timings.kinetic.cycle)
        (renderLine 3 "spd_accel" timings.kinetic.speedAccel)
        (renderLine 3 "ccl_accel" timings.kinetic.cycleAccel)
        (renderLine 3 "spd_max" timings.kinetic.speedMax)
        (renderLine 3 "ccl_max" timings.kinetic.cycleMax)
      ]))
      (renderLine 2 "switching" timings.switching)
      (renderLine 2 "deceleration" timings.deceleration)
      (renderLine 2 "leave_timeout" timings.leaveTimeout)
      (renderLine 2 "repeat_delay" timings.repeatDelay)
      (renderLine 2 "repeat_rate" timings.repeatRate)
      (renderLine 2 "dblclick" timings.doubleClick)
      (renderLine 2 "wheelrate" timings.wheelRate)
    ]);

  renderedBody =
    let
      inherit (cfg) settings;
      inherit (settings) desktop;
      inherit (settings) terminal;
    in
    joinLines [
      (renderElement 1 "cursor" (joinLines [
        (renderLine 2 "style" settings.cursor.style)
        (renderLine 2 "blink" settings.cursor.blink)
        (renderLine 2 "show" settings.cursor.show)
        (renderColorElement 2 "color" settings.cursor.color)
      ]))
      (renderElement 1 "tooltips" (joinLines [
        (renderLine 2 "timeout" settings.tooltips.timeout)
        (renderLine 2 "enabled" settings.tooltips.enabled)
        (renderColorElement 2 "color" settings.tooltips.color)
      ]))
      (renderElement 1 "clipboard" (joinLines [
        (renderPreview 2 settings.clipboard.preview)
        (renderLine 2 "format" settings.clipboard.format)
      ]))
      (renderElement 1 "debug" (joinLines [
        (renderLine 2 "logs" settings.debug.logs)
        (renderLine 2 "overlay" settings.debug.overlay)
        (renderLine 2 "regions" settings.debug.regions)
      ]))
      (renderElement 1 "colors" (joinLines [
        (renderColorElement 2 "window" settings.colors.window)
        (renderColorElement 2 "focus" settings.colors.focus)
        (renderColorElement 2 "brighter" settings.colors.brighter)
        (renderColorElement 2 "shadower" settings.colors.shadower)
        (renderColorElement 2 "warning" settings.colors.warning)
        (renderColorElement 2 "danger" settings.colors.danger)
        (renderColorElement 2 "action" settings.colors.action)
      ]))
      (renderTimings settings.timings)
      (renderElement 1 "desktop" (joinLines [
        (renderElement 2 "viewport" (renderLine 3 "coor" desktop.viewport.coor))
        (renderLine 2 "macstyle" desktop.macStyle)
        (renderLine 2 "windowmax" desktop.windowMax)
        (renderTaskbar desktop.taskbar)
        (renderElement 2 "panel" (joinLines [
          (renderLine 3 "env" desktop.panel.env)
          (renderLine 3 "cmd" desktop.panel.cmd)
          (renderLine 3 "cwd" desktop.panel.cwd)
          (renderLine 3 "height" desktop.panel.height)
        ]))
        (renderElement 2 "background" (joinLines [
          (renderColorElement 3 "color" desktop.background.color)
          (renderLine 3 "tile" desktop.background.tile)
        ]))
      ]))
      (renderElement 1 "terminal" (joinLines [
        (renderLine 2 "sendinput" terminal.sendInput)
        (renderLine 2 "cwdsync" terminal.cwdSync)
        (renderElement 2 "scrollback" (joinLines [
          (renderLine 3 "size" terminal.scrollback.size)
          (renderLine 3 "growstep" terminal.scrollback.growStep)
          (renderLine 3 "growlimit" terminal.scrollback.growLimit)
          (renderLine 3 "maxline" terminal.scrollback.maxLine)
          (renderLine 3 "wrap" terminal.scrollback.wrap)
          (renderScrollbackReset 3 terminal.scrollback.reset)
          (renderLine 3 "altscroll" terminal.scrollback.altScroll)
          (renderLine 3 "oversize" terminal.scrollback.oversize)
        ]))
        (renderTerminalColors 2 terminal.colors)
        (renderLine 2 "border" terminal.border)
        (renderLine 2 "tablen" terminal.tabLength)
        (renderElement 2 "selection" (joinLines [
          (renderLine 3 "mode" terminal.selection.mode)
          (renderLine 3 "rect" terminal.selection.rect)
        ]))
        (renderLine 2 "atexit" terminal.atExit)
        (renderRawSubtree 2 "menu" terminal.menu)
      ]))
      (renderElement 1 "tile" (renderRawSubtree 2 "menu" settings.tile.menu))
      (renderElement 1 "defapp" (renderRawSubtree 2 "menu" settings.defapp.menu))
      (renderElement 1 "events" settings.events)
    ];

  generatedConfig = lib.optionalString (renderedBody != "") "<config>\n${renderedBody}\n</config>";

  renderedRootSubtrees = joinLines [
    (renderRawSubtree 0 "Macro" cfg.settings.rawRoot.macro)
    (renderRawSubtree 0 "Menu" cfg.settings.rawRoot.menu)
    (renderRawSubtree 0 "Ns" cfg.settings.rawRoot.ns)
    (renderRawSubtree 0 "Colors" cfg.settings.rawRoot.colors)
    (renderRawSubtree 0 "X11ColorNames" cfg.settings.rawRoot.x11ColorNames)
    (renderRawSubtree 0 "Terminal" cfg.settings.rawRoot.terminal)
    (renderRawSubtree 0 "Scripting" cfg.settings.rawRoot.scripting)
  ];

  renderedSettings =
    if cfg.settingsText != null then
      cfg.settingsText
    else
      joinLines [
        generatedConfig
        renderedRootSubtrees
        cfg.extraConfig
      ];
in
{
  options.programs.vtm = {
    enable = lib.mkEnableOption "VTM text-based desktop environment";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.vtm;
      defaultText = lib.literalExpression "pkgs.vtm";
      description = "VTM package to install.";
    };

    literal = lib.mkOption {
      type = types.functionTo literalType;
      default = value: {
        _type = "vtmLiteral";
        text = value;
      };
      description = "Wrap a taskbar item string so it renders as an unquoted DynamicXML reference.";
    };

    settingsText = lib.mkOption {
      type = types.nullOr types.lines;
      default = null;
      description = ''
        Full contents for ~/.config/vtm/settings.xml.

        When set, this bypasses the typed settings generator.
      '';
    };

    extraConfig = lib.mkOption {
      type = types.lines;
      default = "";
      description = "Raw DynamicXML root elements appended after generated settings.";
    };

    theme = lib.mkOption {
      type = types.nullOr (types.enum (builtins.attrNames catppuccinThemes));
      default = "catppuccin-mocha";
      description = ''
        Prefabricated VTM theme to apply through typed settings.

        Set to null to disable generated theme defaults.
      '';
    };

    themes = lib.mkOption {
      type = types.attrs;
      default = catppuccinThemes;
      defaultText = lib.literalExpression "Catppuccin Latte, Frappe, Macchiato, and Mocha";
      description = "Prefabricated VTM theme fragments used by programs.vtm.theme.";
    };

    settings = {
      cursor = {
        style = lib.mkOption {
          type = types.nullOr (
            types.enum [
              "bar"
              "block"
              "underline"
            ]
          );
          default = null;
        };

        blink = lib.mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "400ms";
        };

        show = lib.mkOption {
          type = types.nullOr types.bool;
          default = null;
        };

        color = mkColorStyleOption "Cursor colour.";
      };

      tooltips = {
        timeout = lib.mkOption {
          type = nullOrDynamicValue;
          default = null;
          example = "400ms";
        };

        enabled = lib.mkOption {
          type = nullOrBoolToken;
          default = null;
        };

        color = mkColorStyleOption "Tooltip colour.";
      };

      clipboard = {
        preview = {
          enabled = lib.mkOption {
            type = nullOrBoolToken;
            default = null;
          };

          size = lib.mkOption {
            type = nullOrString;
            default = null;
            example = "80,25";
          };

          color = mkColorStyleOption "Clipboard preview colour.";

          alpha = lib.mkOption {
            type = nullOrDynamicValue;
            default = null;
            example = lib.literalExpression "config.programs.vtm.literal \"0xFF\"";
          };

          timeout = lib.mkOption {
            type = nullOrDynamicValue;
            default = null;
            example = "3s";
          };

          shadow = lib.mkOption {
            type = nullOrDynamicValue;
            default = null;
          };
        };

        format = lib.mkOption {
          type = types.nullOr (
            types.enum [
              "text"
              "ansi"
              "rich"
              "html"
              "protected"
            ]
          );
          default = null;
        };
      };

      debug = {
        logs = lib.mkOption {
          type = types.nullOr types.bool;
          default = null;
        };

        overlay = lib.mkOption {
          type = types.nullOr types.bool;
          default = null;
        };

        regions = lib.mkOption {
          type = types.nullOr types.bool;
          default = null;
        };
      };

      colors = {
        window = mkColorStyleOption "Background colour for unfocused windows.";
        focus = mkColorStyleOption "Background colour for focused windows.";
        brighter = mkColorStyleOption "Highlight colour for brightening UI elements.";
        shadower = mkColorStyleOption "Shadow colour for dimming UI elements.";
        warning = mkColorStyleOption "Warning state colour.";
        danger = mkColorStyleOption "Danger or error state colour.";
        action = mkColorStyleOption "Success or action state colour.";
      };

      desktop = {
        viewport.coor = lib.mkOption {
          type = nullOrString;
          default = null;
          example = "0,0";
        };

        macStyle = lib.mkOption {
          type = types.nullOr types.bool;
          default = null;
        };

        windowMax = lib.mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "3000x2000";
        };

        taskbar = {
          wide = lib.mkOption {
            type = types.nullOr types.bool;
            default = null;
          };

          selected = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
          };

          clearItems = lib.mkOption {
            type = types.bool;
            default = false;
            description = "Emit <item*/> before generated taskbar items.";
          };

          items = lib.mkOption {
            type = types.listOf itemType;
            default = [ ];
          };

          autorun = {
            clearRuns = lib.mkOption {
              type = types.bool;
              default = false;
              description = "Emit <run*/> before generated taskbar autorun entries.";
            };

            items = lib.mkOption {
              type = types.listOf autorunItemType;
              default = [ ];
            };
          };

          width = {
            folded = lib.mkOption {
              type = nullOrDynamicValue;
              default = null;
            };

            expanded = lib.mkOption {
              type = nullOrDynamicValue;
              default = null;
            };
          };

          timeout = lib.mkOption {
            type = nullOrDynamicValue;
            default = null;
            example = "250ms";
          };

          colors = {
            background = mkColorStyleOption "Taskbar background colour.";
            focused = mkColorStyleOption "Focused taskbar item colour.";
            selected = mkColorStyleOption "Selected taskbar item colour.";
            active = mkColorStyleOption "Running taskbar item colour.";
            inactive = mkColorStyleOption "Inactive taskbar item colour.";
          };
        };

        panel = {
          env = lib.mkOption {
            type = nullOrString;
            default = null;
          };

          cmd = lib.mkOption {
            type = nullOrString;
            default = null;
          };

          cwd = lib.mkOption {
            type = nullOrString;
            default = null;
          };

          height = lib.mkOption {
            type = nullOrDynamicValue;
            default = null;
          };
        };

        background = {
          color = mkColorStyleOption "Desktop background colour.";

          tile = lib.mkOption {
            type = nullOrString;
            default = null;
            description = "Optional truecolour ANSI-art tile for the desktop background.";
          };
        };
      };

      terminal = {
        sendInput = lib.mkOption {
          type = nullOrString;
          default = null;
          example = "echo \\\"test\\\"\\n";
        };

        cwdSync = lib.mkOption {
          type = nullOrString;
          default = null;
          example = " cd $P\\n";
        };

        scrollback = {
          size = lib.mkOption {
            type = types.nullOr types.ints.positive;
            default = null;
          };

          growStep = lib.mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
          };

          growLimit = lib.mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
          };

          maxLine = lib.mkOption {
            type = types.nullOr types.ints.positive;
            default = null;
          };

          wrap = lib.mkOption {
            type = types.nullOr types.bool;
            default = null;
          };

          reset = {
            onKey = lib.mkOption {
              type = nullOrBoolToken;
              default = null;
            };

            onOutput = lib.mkOption {
              type = nullOrBoolToken;
              default = null;
            };
          };

          altScroll = lib.mkOption {
            type = types.nullOr types.bool;
            default = null;
          };

          oversize = lib.mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
          };
        };

        colors = {
          palette = lib.mkOption {
            type = terminalPaletteType;
            default = [ ];
            description = "Terminal 16-colour palette rendered as raw DynamicXML color0 through color15 entries.";
          };

          default = mkColorStyleOption "Default terminal foreground and background colours.";
          match = mkColorStyleOption "Selected text match colour.";

          selection = {
            text = mkColorStyleOption "Plaintext selection colour.";
            protected = mkColorStyleOption "Protected clipboard selection colour.";
            ansi = mkColorStyleOption "ANSI clipboard selection colour.";
            rich = mkColorStyleOption "Rich clipboard selection colour.";
            html = mkColorStyleOption "HTML clipboard selection colour.";
            none = mkColorStyleOption "Inactive selection colour.";
          };

          names = lib.mkOption {
            type = rawSubtreeType "Raw DynamicXML body rendered inside <terminal><colors><names> for OSC colour name mappings.";
            default = { };
          };
        };

        border = lib.mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
        };

        tabLength = lib.mkOption {
          type = types.nullOr types.ints.positive;
          default = null;
        };

        selection = {
          mode = lib.mkOption {
            type = types.nullOr (
              types.enum [
                "text"
                "ansi"
                "rich"
                "html"
                "protected"
                "none"
              ]
            );
            default = null;
          };

          rect = lib.mkOption {
            type = types.nullOr types.bool;
            default = null;
          };
        };

        atExit = lib.mkOption {
          type = types.nullOr (
            types.enum [
              "auto"
              "ask"
              "close"
              "restart"
              "retry"
            ]
          );
          default = null;
        };

        menu = lib.mkOption {
          type = rawSubtreeType "Raw DynamicXML body rendered inside <terminal><menu> for terminal menu customisation.";
          default = { };
        };
      };

      timings = {
        fps = lib.mkOption {
          type = nullOrDynamicValue;
          default = null;
        };

        kinetic = {
          speed = lib.mkOption {
            type = nullOrDynamicValue;
            default = null;
          };

          pulse = lib.mkOption {
            type = nullOrDynamicValue;
            default = null;
          };

          cycle = lib.mkOption {
            type = nullOrDynamicValue;
            default = null;
          };

          speedAccel = lib.mkOption {
            type = nullOrDynamicValue;
            default = null;
          };

          cycleAccel = lib.mkOption {
            type = nullOrDynamicValue;
            default = null;
          };

          speedMax = lib.mkOption {
            type = nullOrDynamicValue;
            default = null;
          };

          cycleMax = lib.mkOption {
            type = nullOrDynamicValue;
            default = null;
          };
        };

        switching = lib.mkOption {
          type = nullOrDynamicValue;
          default = null;
          example = "200ms";
        };

        deceleration = lib.mkOption {
          type = nullOrDynamicValue;
          default = null;
          example = "2s";
        };

        leaveTimeout = lib.mkOption {
          type = nullOrDynamicValue;
          default = null;
          example = "1s";
        };

        repeatDelay = lib.mkOption {
          type = nullOrDynamicValue;
          default = null;
          example = "500ms";
        };

        repeatRate = lib.mkOption {
          type = nullOrDynamicValue;
          default = null;
          example = "30ms";
        };

        doubleClick = lib.mkOption {
          type = nullOrDynamicValue;
          default = null;
          example = "500ms";
        };

        wheelRate = lib.mkOption {
          type = nullOrDynamicValue;
          default = null;
        };
      };

      tile.menu = lib.mkOption {
        type = rawSubtreeType "Raw DynamicXML body rendered inside <tile><menu> for tiling menu customisation.";
        default = { };
      };

      defapp.menu = lib.mkOption {
        type = rawSubtreeType "Raw DynamicXML body rendered inside <defapp><menu> for default application menu customisation.";
        default = { };
      };

      events = lib.mkOption {
        type = types.lines;
        default = "";
        description = "Raw DynamicXML body rendered inside <config><events> for event bindings.";
      };

      rawRoot = {
        macro = lib.mkOption {
          type = rawSubtreeType "Raw DynamicXML body rendered inside root <Macro>.";
          default = { };
        };

        menu = lib.mkOption {
          type = rawSubtreeType "Raw DynamicXML body rendered inside root <Menu>.";
          default = { };
        };

        ns = lib.mkOption {
          type = rawSubtreeType "Raw DynamicXML body rendered inside root <Ns>.";
          default = { };
        };

        colors = lib.mkOption {
          type = rawSubtreeType "Raw DynamicXML body rendered inside root <Colors>.";
          default = { };
        };

        x11ColorNames = lib.mkOption {
          type = rawSubtreeType "Raw DynamicXML body rendered inside root <X11ColorNames>.";
          default = { };
        };

        terminal = lib.mkOption {
          type = rawSubtreeType "Raw DynamicXML body rendered inside root <Terminal>.";
          default = { };
        };

        scripting = lib.mkOption {
          type = rawSubtreeType "Raw DynamicXML body rendered inside root <Scripting>.";
          default = { };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf (cfg.theme != null) {
        programs.vtm.settings = themeSettings;
      })
      {
        home.packages = [ cfg.package ];

        xdg.configFile."vtm/settings.xml".text = renderedSettings;
      }
    ]
  );
}
