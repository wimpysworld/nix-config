# rsync-send

Mirror one directory below your local home to the same relative path below your remote home:

```bash
rsync-send ~/Test/fiddle wibble
rsync-send "$HOME/Test/fiddle" someone@wibble
```

The first command sends the contents to `wibble:./Test/fiddle/`. SSH configuration selects the remote username and connection route. `user@host` overrides the username. SSH aliases, DNS names, and IPv4 addresses are accepted. Use an SSH alias for IPv6 addresses or custom ports.

The script creates missing remote parents. Both paths have a trailing slash, so the transfer copies directory contents without another directory level.

**Extra entries within the selected destination are deleted.** The mirror uses the existing `rsync-mirror` flags, including `--inplace` and `--partial`. Interrupted updates can leave partial destination files. File selection uses normal rsync size and modification-time checks, not forced checksums.

## Safety boundaries

The source must be an existing readable directory strictly below `$HOME`. The script rejects home itself, root, outside-home paths, and symlink components below home. A path that temporarily leaves home through `..` is also rejected. A symlink at the home boundary is supported. Symlinks inside the source remain symlinks because the transfer uses `--archive`.

The remote helper checks every destination component before creation and again when rsync connects. It rejects symlinks, non-directories, root, home itself, and paths that escape home. The helper uses the remote physical home, which can differ from the local home path.

Remote requirements are SSH access, POSIX `sh`, `mkdir`, and rsync 3.0.0 or newer on `PATH`. Argument transport supports POSIX and fish login shells. Restricted shells that reject `sh -c` or rsync secluded arguments are not supported.

Do not change source or destination path components during a transfer. Checks cannot prevent concurrent filesystem changes between validation and use. The remote account and its shell configuration must be trusted.

## Tests

The package build runs `test-rsync-send.sh` through `postCheck`. Tests use temporary local homes, isolated command paths, and mocked SSH and rsync. They check path rejection, destination creation, failure ordering, exact mirror arguments, and quoting through POSIX and fish shells. They never transfer files.

Run the same checks without a package build:

```bash
TEST_FISH="$(command -v fish)" bash home-manager/_mixins/scripts/rsync-send/test-rsync-send.sh \
  home-manager/_mixins/scripts/rsync-send/rsync-send.sh
```
