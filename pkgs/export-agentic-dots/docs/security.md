# Security policy

The export uses named allowlists for agents, commands, and skills. It does not infer public status from the absence of an encrypted marker.

The export excludes encrypted commands and skills, encrypted catalogue rows, Google Workspace resources, personal notebook resources, credentials, trust configuration, runtime data, SOPS placeholders, and absolute home or Nix store paths.

The export also defers Fence, host and service wrappers, Herdr socket integration, private provider models, and hooks that require generated machine paths.

The portable global instruction body is a narrow projection. It does not copy claims about unavailable sandbox policy, pull request monitoring, or host-specific write helpers.

The exporter stages all desired files before it writes the destination. It rejects path traversal, symbolic links, duplicate paths, unowned conflicts, changed owned files, and unsupported modes. It reports stale owned files without deleting them.

Treat every exported assistant instruction as executable policy. Review the generated files and dependencies before installation.
