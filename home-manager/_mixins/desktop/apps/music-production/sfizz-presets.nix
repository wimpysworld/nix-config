{
  lib,
  linkFarm,
  writeText,
  karoryfer-black-and-green-guitars,
  karoryfer-growlybass,
  freepats-synthesizer-percussion,
  karoryfer-big-rusty-drums,
  virtuosity-drums,
  project16-rickenbacker-4001,
  unreal-the-slapper,
  karoryfer-pastabass,
  karoryfer-black-and-blue-basses,
}:
let
  guitars = "${karoryfer-black-and-green-guitars}/share/sfz/karoryfer-black-and-green-guitars/Programs";
  bass = "${karoryfer-growlybass}/share/sfz/karoryfer-growlybass";
  bigRusty = "${karoryfer-big-rusty-drums}/share/sfz/karoryfer-big-rusty-drums/Programs";
  virtuosity = "${virtuosity-drums}/share/sfz/virtuosity-drums/Programs-sfizz";
  rickenbacker = "${project16-rickenbacker-4001}/share/sfz/project16-rickenbacker-4001";
  slapper = "${unreal-the-slapper}/share/sfz/unreal-the-slapper";
  pastabass = "${karoryfer-pastabass}/share/sfz/karoryfer-pastabass/Pastabass";
  blackAndBlue = "${karoryfer-black-and-blue-basses}/share/sfz/karoryfer-black-and-blue-basses/Programs-sfizz";
  presets = [
    {
      name = "darkblack-clean";
      label = "Karoryfer - Darkblack Clean (sfizz)";
      file = "${blackAndBlue}/01-darkblack_keysw.sfz";
    }
    {
      name = "babyblue-clean";
      label = "Karoryfer - Babyblue Clean (sfizz)";
      file = "${blackAndBlue}/03-babyblue_all.sfz";
    }
    {
      name = "slapper-acoustic";
      namespace = "unreal-instruments";
      label = "Unreal Instruments - The Slapper (acoustic)";
      file = "${slapper}/AG-Slapper/AG-Slapper/#AG-Slapper.sfz";
    }
    {
      name = "slapper-electric";
      namespace = "unreal-instruments";
      label = "Unreal Instruments - The Slapper (electric)";
      file = "${slapper}/EG-Slapper/EG-Slapper/#EG-Slapper.sfz";
    }
    {
      name = "pastabass-spaghetti";
      label = "Karoryfer - Pastabass (spaghetti)";
      file = "${pastabass}/spaghetti.sfz";
    }
    {
      name = "pastabass-linguine";
      label = "Karoryfer - Pastabass (linguine)";
      file = "${pastabass}/linguine.sfz";
    }
    {
      name = "pastabass-tagliatelle";
      label = "Karoryfer - Pastabass (tagliatelle)";
      file = "${pastabass}/tagliatelle.sfz";
    }
    {
      name = "pastabass-fetuccine";
      label = "Karoryfer - Pastabass (fetuccine)";
      file = "${pastabass}/fetuccine.sfz";
    }
    {
      name = "rickenbacker-fingered";
      namespace = "project16";
      label = "Project16 - Rickenbacker (fingered 1)";
      file = "${rickenbacker}/Fingered and Picked/Fingered1.sfz";
    }
    {
      name = "rickenbacker-picked";
      namespace = "project16";
      label = "Project16 - Rickenbacker (picked 1)";
      file = "${rickenbacker}/Fingered and Picked/Picked1.sfz";
    }
    {
      name = "rickenbacker-fingered2";
      namespace = "project16";
      label = "Project16 - Rickenbacker (fingered 2)";
      file = "${rickenbacker}/Fingered and Picked/Fingered2.sfz";
    }
    {
      name = "rickenbacker-picked2";
      namespace = "project16";
      label = "Project16 - Rickenbacker (picked 2)";
      file = "${rickenbacker}/Fingered and Picked/Picked2.sfz";
    }
    {
      name = "rickenbacker-fingered-muted";
      namespace = "project16";
      label = "Project16 - Rickenbacker (fingered 1 muted)";
      file = "${rickenbacker}/Muted/Fingered1_Muted.sfz";
    }
    {
      name = "rickenbacker-picked-muted";
      namespace = "project16";
      label = "Project16 - Rickenbacker (picked 1 muted)";
      file = "${rickenbacker}/Muted/Picked1_Muted.sfz";
    }
    {
      name = "rickenbacker-fingered2-muted";
      namespace = "project16";
      label = "Project16 - Rickenbacker (fingered 2 muted)";
      file = "${rickenbacker}/Muted/Fingered2_Muted.sfz";
    }
    {
      name = "rickenbacker-picked2-muted";
      namespace = "project16";
      label = "Project16 - Rickenbacker (picked 2 muted)";
      file = "${rickenbacker}/Muted/Picked2_Muted.sfz";
    }
    {
      name = "rickenbacker-slap1-long";
      namespace = "project16";
      label = "Project16 - Rickenbacker (slap 1 long)";
      file = "${rickenbacker}/Slapped/Slap1_Long.sfz";
    }
    {
      name = "rickenbacker-slap1-short";
      namespace = "project16";
      label = "Project16 - Rickenbacker (slap 1 short)";
      file = "${rickenbacker}/Slapped/Slap1_Short.sfz";
    }
    {
      name = "rickenbacker-slap2-long";
      namespace = "project16";
      label = "Project16 - Rickenbacker (slap 2 long)";
      file = "${rickenbacker}/Slapped/Slap2_Long.sfz";
    }
    {
      name = "rickenbacker-slap2-short";
      namespace = "project16";
      label = "Project16 - Rickenbacker (slap 2 short)";
      file = "${rickenbacker}/Slapped/Slap2_Short.sfz";
    }
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
    {
      name = "synthesizer-percussion";
      namespace = "freepats";
      label = "FreePats - Synthesizer percussion";
      file = "${freepats-synthesizer-percussion}/share/sfz/freepats-synthesizer-percussion/SynthesizerPercussion-20220718.sfz";
    }
    {
      name = "big-rusty-full";
      label = "Karoryfer - Big Rusty Drums (full kit)";
      file = "${karoryfer-big-rusty-drums}/share/sfz/karoryfer-big-rusty-drums/Programs-sfizz/01-full.sfz";
    }
    {
      name = "big-rusty-basic";
      label = "Karoryfer - Big Rusty Drums (basic kit)";
      file = "${bigRusty}/02-basic.sfz";
    }
    {
      name = "big-rusty-kick";
      label = "Karoryfer - Big Rusty Drums (kick bus)";
      file = "${bigRusty}/03-kick.sfz";
    }
    {
      name = "big-rusty-snare";
      label = "Karoryfer - Big Rusty Drums (snare bus)";
      file = "${bigRusty}/04-snare.sfz";
    }
    {
      name = "big-rusty-toms";
      label = "Karoryfer - Big Rusty Drums (tom bus)";
      file = "${bigRusty}/05-toms.sfz";
    }
    {
      name = "big-rusty-hihat";
      label = "Karoryfer - Big Rusty Drums (hi-hat bus)";
      file = "${bigRusty}/06-hihat.sfz";
    }
    {
      name = "big-rusty-cymbals";
      label = "Karoryfer - Big Rusty Drums (cymbal bus)";
      file = "${bigRusty}/07-cymbals.sfz";
    }
    {
      name = "big-rusty-noises";
      label = "Karoryfer - Big Rusty Drums (noise and click bus)";
      file = "${bigRusty}/08-noises.sfz";
    }
    {
      name = "virtuosity-basic";
      namespace = "versilian";
      label = "Virtuosity Drums - Basic kit";
      file = "${virtuosity}/01-basic-kit.sfz";
    }
    {
      name = "virtuosity-full";
      namespace = "versilian";
      label = "Virtuosity Drums - Full kit";
      file = "${virtuosity}/02-full-kit.sfz";
    }
    {
      name = "virtuosity-kick-mic";
      namespace = "versilian";
      label = "Virtuosity Drums - Kick mic";
      file = "${virtuosity}/03-kick-mic.sfz";
    }
    {
      name = "virtuosity-snare-mic";
      namespace = "versilian";
      label = "Virtuosity Drums - Snare mic";
      file = "${virtuosity}/04-snare-mic.sfz";
    }
    {
      name = "virtuosity-oh-mic";
      namespace = "versilian";
      label = "Virtuosity Drums - Overhead mic";
      file = "${virtuosity}/05-oh-mic.sfz";
    }
    {
      name = "virtuosity-mid-mic";
      namespace = "versilian";
      label = "Virtuosity Drums - Mid mic";
      file = "${virtuosity}/06-mid-mic.sfz";
    }
    {
      name = "virtuosity-room-mic";
      namespace = "versilian";
      label = "Virtuosity Drums - Room mic";
      file = "${virtuosity}/07-room-mic.sfz";
    }
    {
      name = "virtuosity-vintage-mic";
      namespace = "versilian";
      label = "Virtuosity Drums - Vintage mic";
      file = "${virtuosity}/08-vintage-mic.sfz";
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
      <urn:${preset.namespace or "karoryfer"}:sfizz:${preset.name}>
        a pset:Preset ;
        lv2:appliesTo <http://sfztools.github.io/sfizz> ;
        rdfs:label ${builtins.toJSON preset.label} ;
        rdfs:seeAlso <presets.ttl> .
    '') presets;
  states =
    prefixes
    + lib.concatMapStringsSep "\n" (preset: ''
      <urn:${preset.namespace or "karoryfer"}:sfizz:${preset.name}>
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
