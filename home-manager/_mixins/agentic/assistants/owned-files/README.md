# Owned assistant files

`deploy.py` updates explicit generated destinations without clearing client directories. Home Manager packages it as `deploy-owned-agent-files` and supplies the deployment specification during activation.

See [activation ownership and cleanup](../README.md#activation-ownership-and-cleanup) for ownership rules, migration, conflict handling, and transaction limits.

## Tests

From the repository root, run:

```console
python3 home-manager/_mixins/agentic/assistants/owned-files/test_deploy.py
```

The tests create temporary homes and synthetic sources. They do not activate Home Manager, read real secrets, or change the active client configuration.

The tests check removals, renames, client disablement, manual-file preservation, conflicts, symlink boundaries, missing sources, dry runs, one-off retirement, and rollback after an injected failure.

Use the test harness for experiments. Do not invoke the deployer manually against your real home directory.
