{
  lib,
  linkFarm,
  writeText,
  karoryfer-black-and-green-guitars,
  karoryfer-growlybass,
}:
let
  guitars = "${karoryfer-black-and-green-guitars}/share/sfz/karoryfer-black-and-green-guitars/Programs";
  bass = "${karoryfer-growlybass}/share/sfz/karoryfer-growlybass";
  presets = [
    {
      name = "green-keyswitch";
      label = "Karoryfer - Green guitar (keyswitch)";
      file = "${guitars}/01-green_keyswitch.sfz";
    }
    {
      name = "black-keyswitch";
      label = "Karoryfer - Black guitar (keyswitch)";
      file = "${guitars}/02-black_keyswitch.sfz";
    }
    {
      name = "green-twang";
      label = "Karoryfer - Green guitar (twang)";
      file = "${guitars}/04-green_twang.sfz";
    }
    {
      name = "growlybass-clean";
      label = "Karoryfer - Growlybass (clean)";
      file = "${bass}/growlybass_clean.sfz";
    }
    {
      name = "growlybass-dirty";
      label = "Karoryfer - Growlybass (dirty)";
      file = "${bass}/growlybass_dirty.sfz";
    }
  ];
  prefixes = ''
    @prefix atom: <http://lv2plug.in/ns/ext/atom#> .
    @prefix lv2: <http://lv2plug.in/ns/lv2core#> .
    @prefix pset: <http://lv2plug.in/ns/ext/presets#> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix state: <http://lv2plug.in/ns/ext/state#> .
  '';
  manifest =
    prefixes
    + lib.concatMapStringsSep "\n" (preset: ''
      <urn:karoryfer:sfizz:${preset.name}>
        a pset:Preset ;
        lv2:appliesTo <http://sfztools.github.io/sfizz> ;
        rdfs:label ${builtins.toJSON preset.label} ;
        rdfs:seeAlso <presets.ttl> .
    '') presets;
  states =
    prefixes
    + lib.concatMapStringsSep "\n" (preset: ''
      <urn:karoryfer:sfizz:${preset.name}>
        a pset:Preset ;
        lv2:appliesTo <http://sfztools.github.io/sfizz> ;
        rdfs:label ${builtins.toJSON preset.label} ;
        state:state [
          <http://sfztools.github.io/sfizz:sfzfile> ${builtins.toJSON preset.file}^^atom:Path
        ] .
    '') presets;
in
linkFarm "karoryfer-sfizz-presets" [
  {
    name = "lib/lv2/karoryfer-sfizz-presets.lv2/manifest.ttl";
    path = writeText "karoryfer-sfizz-manifest.ttl" manifest;
  }
  {
    name = "lib/lv2/karoryfer-sfizz-presets.lv2/presets.ttl";
    path = writeText "karoryfer-sfizz-presets.ttl" states;
  }
]
