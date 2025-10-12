{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  gtk3,
  git,
  python3,
  sassc,
  nix-update-script,
  accents ? [ "blue" ],
  size ? "standard",
  tweaks ? [ ],
  variant ? "mocha",
}:
let
  validAccents = [
    "blue"
    "flamingo"
    "green"
    "lavender"
    "maroon"
    "mauve"
    "peach"
    "pink"
    "red"
    "rosewater"
    "sapphire"
    "sky"
    "teal"
    "yellow"
  ];
  validSizes = [
    "standard"
    "compact"
  ];
  validTweaks = [
    "black"
    "rimless"
    "normal"
    "float"
  ];
  validVariants = [
    "latte"
    "frappe"
    "macchiato"
    "mocha"
  ];

  pname = "catppuccin-gtk";
  version = "1.0.4-unstable-20250528";
in

lib.checkListOfEnum "${pname}: theme accent" validAccents accents lib.checkListOfEnum
  "${pname}: color variant"
  validVariants
  [ variant ]
  lib.checkListOfEnum
  "${pname}: size variant"
  validSizes
  [ size ]
  lib.checkListOfEnum
  "${pname}: tweaks"
  validTweaks
  tweaks

  stdenvNoCC.mkDerivation
  {
    inherit pname version;

    src = fetchFromGitHub {
      owner = "VanillaDaFur";
      repo = "catppuccin-gtk";
      #tag = "v${version}";
      rev = "07bef8cedda75ef42a4bac6f9ac5afc88d1ba062";
      fetchSubmodules = true;
      hash = "sha256-QUpkKAm/rxbXc7AYdiHJXx4LRjSG73c6jBcIfVn6Y2M=";
    };

    nativeBuildInputs = [
      gtk3
      sassc
      # git is needed here since "git apply" is being used for patches
      # see <https://github.com/catppuccin/gtk/blob/4173b70b910bbb3a42ef0e329b3e98d53cef3350/build.py#L465>
      git
      (python3.withPackages (ps: [ ps.catppuccin ]))
    ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/themes

      python3 build.py ${variant} \
        --accent ${toString accents} \
        ${lib.optionalString (size != [ ]) "--size " + size} \
        ${lib.optionalString (tweaks != [ ]) "--tweaks " + toString tweaks} \
        --dest $out/share/themes

      runHook postInstall
    '';

    passthru.updateScript = nix-update-script { };

    meta = {
      description = "Soothing pastel theme for GTK";
      homepage = "https://github.com/catppuccin/gtk";
      license = lib.licenses.gpl3Plus;
      platforms = lib.platforms.all;
      maintainers = with lib.maintainers; [
        fufexan
        dixslyf
        isabelroses
      ];
    };
  }
