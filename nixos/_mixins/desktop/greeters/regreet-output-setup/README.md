# ReGreet output setup

`greetd.nix` runs this helper synchronously inside Cage for every host with a registry primary display, including hosts with the `reframe` tag. ReGreet starts only after output verification. Hosts without a registry display bypass the helper.

The greeter does not run kanshi or restore an all-display layout. User-session ReFrame monitor configuration remains separate and unchanged.

At startup, the helper queries `wlr-randr --json` and selects the connected registry primary. If the primary is absent, it logs a fallback. The fallback is the first enabled output by name, or the first available output by name if none is enabled.

The helper enables the selected output at position `0,0` and at the registry scale of the primary display. Cage has no scale option, so without the helper the greeter renders at scale `1`, smaller than the user session on scaled outputs. It disables every other discovered output, including outputs absent from the registry. A supported registry mode takes precedence on the primary. Otherwise, it selects the current mode, the preferred mode, or the first supported mode sorted by width, height and refresh. Refresh matching uses millihertz precision.

The helper verifies that exactly the selected output is enabled, with the requested position and a scale within 0.01 of the request, before it executes the session command. Query, apply and verification failures stop startup with a log message. Each `wlr-randr` call has a five-second timeout and a one-second forced termination limit. There are no retries or all-output fallback.

Cage retains `-m last` for initial output selection. This helper defines startup behaviour only, not a hotplug policy.

## Fixture tests

From the repository root, run:

```sh
python3 nixos/_mixins/desktop/greeters/regreet-output-setup/tests/test-startup.py -v
shellcheck nixos/_mixins/desktop/greeters/regreet-output-setup/regreet-output-setup.sh
```

The flake check `checks.<system>.regreet-output-setup` runs the Python tests. The tests include registry-based fixtures for ReFrame multi-monitor hosts, with primary selection, secondary-output shutdown and a missing-primary fallback. `skrye` is the current multi-monitor ReFrame host. Other tests cover a fractional registry scale, a fixed-point scale report and an invalid scale.

The tests require Bash, Python 3.11 or newer, jq and GNU timeout. They replace `wlr-randr` and ReGreet with temporary test programs and remove Wayland connection variables. Do not run the helper directly against a live compositor for validation.
