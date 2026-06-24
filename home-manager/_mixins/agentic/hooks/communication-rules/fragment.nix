{ lib }:
let
  text = lib.trim (builtins.readFile ./communication-rules.md);
in
{
  inherit text;

  section = ''
    ## Communication Rules

    ${text}
  '';

  reminderPrompt = ''
    Reminder: Follow the Communication Rules for any prose you produce or write.

    Communication Rules:
    ${text}
  '';

  blockMessage = ''
    Blocked. Revise this prose to follow the Communication Rules.

    Communication Rules:
    ${text}
  '';

  correctionPrompt = ''
    Your previous reply broke the Communication Rules. Apply them to this reply and every reply that follows. Do not resend or rewrite the previous reply.

    Communication Rules:
    ${text}
  '';

  b1RevisionPrompt = ''
    The file you wrote breaks the Communication Rules. Revise it in place to comply: {target}. Do not rewrite unrelated content.

    Communication Rules:
    ${text}
  '';

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

    hardGateBannedTerms = [
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
    ];

    # These terms are told to the model but deliberately not hard-gated. Each
    # has common legitimate uses, such as vital signs, foster care, and landscape
    # orientation, so gating them would cause false-positive blocks.
    promptOnlyBannedTerms = [
      "landscape"
      "foster"
      "vital"
    ];

    bannedWordGroups = {
      filler = [
        "really"
        "basically"
        "actually"
        "simply"
      ];
      pleasantries = [
        "sure"
        "certainly"
        "of course"
        "happy to"
      ];
      hedges = [
        "perhaps"
        "might want to"
        "could possibly"
        "is likely"
      ];
      llmTells = [
        "pivotal"
        "crucial"
        "vital"
        "testament"
        "seamless"
        "robust"
        "cutting-edge"
        "delve"
        "leverage"
        "multifaceted"
        "foster"
        "realm"
        "tapestry"
        "vibrant"
        "nuanced"
        "intricate"
        "showcasing"
        "streamline"
        "landscape"
        "garnered"
        "underpinning"
        "underscores"
      ];
    };

    # Post-detection data shared by every Tier B adapter. fragment.nix is the
    # single canonical source; adapters read these via policy.json (TS) or the
    # TRIPWIRE_POLICY_JSON env (Python) and fall back to baked copies only when
    # the policy file is absent, such as in the fixture harnesses.
    postDetection = {
      # Verb fragments that mark an MCP tool leaf as able to post or mutate
      # external state. Matched against the leaf after the final "__".
      postToolTerms = [
        "comment"
        "create"
        "edit"
        "post"
        "publish"
        "reply"
        "review"
        "send"
        "submit"
        "update"
        "write"
      ];

      # Text-bearing keys inside a post-capable tool's structured input. Their
      # string values carry the prose that lands on the external surface.
      postTextKeys = [
        "body"
        "comment"
        "comments"
        "content"
        "description"
        "message"
        "messages"
        "note"
        "notes"
        "review"
        "summary"
        "text"
        "title"
      ];

      # Identifier keys used to name the external post destination in the B2
      # yield notice, in preference order. The first present value wins.
      externalTargetKeys = [
        "url"
        "pull_number"
        "issue_number"
        "number"
        "pullRequestId"
        "issueId"
        "discussionId"
        "id"
        "path"
        "repo"
        "repository"
        "owner"
      ];
    };

    scan = {
      stripFencedCodeBlocks = true;
      userPrompts = "ignore";
      sessionStart = "remind";
      incomingToolOutput = "ignore";
      failureMode = {
        reminders = "open";
        writeSurfaces = "closed";
        editSurfaces = "closed";
        postSurfaces = "closed";
        unresolvablePostBodies = "closed";
      };
    };
  };
}
