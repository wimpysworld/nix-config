# ReGreet output setup

`greetd.nix` runs this helper synchronously inside Cage for every multi-monitor host, including hosts with the `reframe` tag. ReGreet starts only after output verification. Single-monitor hosts bypass the helper.

The greeter does not run kanshi or restore an all-display layout. User-session ReFrame monitor configuration remains separate and unchanged.

At startup, the helper queries `wlr-randr --json` and selects the connected registry primary. If the primary is absent, it logs a fallback. The fallback is the first enabled output by name, or the first available output by name if none is enabled.

The helper enables the selected output at position `0,0` and scale `1`. It disables every other discovered output, including outputs absent from the registry. A supported registry mode takes precedence on the primary. Otherwise, it selects the current mode, the preferred mode, or the first supported mode sorted by width, height and refresh. Refresh matching uses millihertz precision.

The helper verifies that exactly the selected output is enabled, with the requested position and scale, before it executes the session command. Query, apply and verification failures stop startup with a log message. Each `wlr-randr` call has a five-second timeout and a one-second forced termination limit. There are no retries or all-output fallback.

Cage retains `-m last` for initial output selection. This helper defines startup behaviour only, not a hotplug policy.

## Fixture tests

From the repository root, run:

```sh
python3 nixos/_mixins/desktop/greeters/regreet-output-setup/tests/test-startup.py -v
shellcheck nixos/_mixins/desktop/greeters/regreet-output-setup/regreet-output-setup.sh
```

The tests include registry-based fixtures for ReFrame multi-monitor hosts, with primary selection, secondary-output shutdown and a missing-primary fallback. `skrye` is the current multi-monitor ReFrame host. `zannah` is a single-monitor ReFrame host for the startup bypass check during integrated evaluation.

The tests require Bash, Python 3.11 or newer, jq and GNU timeout. They replace `wlr-randr` and ReGreet with temporary test programs and remove Wayland connection variables. Do not run the helper directly against a live compositor for validation.
