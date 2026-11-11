{ lib }:
let
  # The canonical rules body, shared with every other consumer through
  # compose.nix, which strips the output-style frontmatter from
  # house-style.md.
  text = (import ../../assistants/compose.nix { inherit lib; }).houseStyleBody;
in
{
  inherit text;

  detectionPolicy = {
    blockedCodepoints = [
      {
        codepoint = "U+2014";
        name = "em dash";
      }
      {
        codepoint = "U+2013";
        name = "en dash";
      }
    ];

    advisoryTerms = [
      "delve"
      "leverage"
      "tapestry"
      "robust"
      "seamless"
      "pivotal"
      "crucial"
      "testament"
      "cutting-edge"
      "multifaceted"
      "realm"
      "vibrant"
      "nuanced"
      "intricate"
      "showcasing"
      "streamline"
      "garnered"
      "underpinning"
      "underscores"
      "boasts"
    ];

  };
}
