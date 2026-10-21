# Headless run

Run an Ebitengine app (any type that implements `ebiten.Game`) headless and programmatically, with no visible window and no change to the source of the app.
Use it to test, debug, or take screenshots. The procedure also applies to a Guigui app.
All reference paths are relative to the skill root.

## Contents

- [Overview](#overview)
- [How it works](#how-it-works)
- [The endpoint](#the-endpoint)
- [The driver](#the-driver)
- [When to use a headless run](#when-to-use-a-headless-run)
- [When not to use a headless run](#when-not-to-use-a-headless-run)
- [Recipe](#recipe)
- [Verifying a run](#verifying-a-run)
- [How the driver drives the guest](#how-the-driver-drives-the-guest)
- [Ticks and TPS](#ticks-and-tps)
- [Observing audio](#observing-audio)
- [Gotchas](#gotchas)
- [Alternative in the Ebitengine repository: a Go test](#alternative-in-the-ebitengine-repository-a-go-test)

## Overview

Upstream wrote and verified this procedure against ebiten commit `7de1780bd` (2026-09-27).
`exp/vmhost` is experimental. If its API changed after that commit, the driver and the snippets here can be out of date. Report drift to the user.

A small **host** program runs the app as a **guest** of the `exp/vmhost` package.
The host controls the ticks of the guest as it wants: one at a time, many in each host frame, or free-running.
The host injects input, reads back rendered frames, and observes the audio that the app plays, all from a hidden window.
The app under test does not change.

## How it works

Only the host uses a GPU or a display. The guest is fully headless.

- The **guest** is the app under test. Its `ebiten.RunGame` connects to the host over a socket *instead of opening a window*.
  It forwards its graphics commands, and it does not render them.
- The **host** is the small driver that you run. It is an `ebiten.Game` itself, with `ebiten.SetWindowVisible(false)`, so it has no visible window.
  It replays the draw commands of the guest on the real GPU. It exposes a `vmhost.GuestSession` to do these actions:
  step the guest (`AdvanceTicks`/`AdvanceFrame`/`WaitFrame`/`CompositeFrame`), inject input, read pixels back, and observe the audio that the guest plays.

## The endpoint

The guest connects to the host through an **endpoint**. The endpoint is the address of the host listener as a URL, for example `unix:///path/to/socket` or `tcp://127.0.0.1:PORT`.
The driver makes one from its listener with `vmhost.EndpointURLFromAddr`.
The guest gets the endpoint in one of two ways:

- When you build the guest with `-tags ebitenginevmguest`, it reads the `EBITENGINE_VM_ENDPOINT` environment variable.
  This needs no source change, and the driver uses this method.
- With no build tag, the code of the app sets `RunGameOptions.VMGuestEndpoint`.

## The driver

The host driver is `scripts/headless-driver/main.go`, relative to the skill root.
In the commands below, `<skill-root>` is the directory that contains the `SKILL.md` of this skill.
Treat the driver as a **starting-point template**, not a finished tool.
Copy it, and adapt the input script, the assertions, and the screen size to your case.
It runs unchanged only for the trivial screenshot (recipe step 1).
It is a skill asset, not a stable command, so do not depend on its flags.

## When to use a headless run

- You must **inject input** (keys, mouse, wheel, runes, touches, gamepads) and observe how the app responds.
  For example, a bug that occurs only after a sequence of clicks, drags, or keystrokes.
- You must **fast-forward to a state and assert it**. Advance N ticks deterministically, then check the resulting frame.
  The run is compressed, so a long run is almost instant, not real-time. To step frame by frame, interleave the calls.
- You want a **golden-image or pixel assertion**, with no human to run the app and paste a screenshot.
- You want only a **screenshot** of the app. Run the driver with no input script, and dump the frame after N ticks (recipe step 1).
- You want to **check audio**. Verify that the app plays the expected sound, at the expected sample rate and volume.
  You get raw PCM for each player (not mixed), and nothing plays.

## When not to use a headless run

- You test pure logic with no rendering. Write an ordinary Go test.
- The target platform is android, ios, or js. `vmhost` is desktop-only.

## Recipe

All the steps use the driver at `scripts/headless-driver/main.go`. Step 1 runs a copy of it unchanged. Steps 2 and 3 copy it and adapt it.
The Go snippets below are excerpts of its `Update`.
Thus, `d.guest` (the `*vmhost.GuestSession`), `d.screen`, and `*ticks` (the value of the `-ticks` flag) are identifiers of the driver.

Run these examples from the **root of the ebiten repository**, because the `-pkg ./examples/...` paths below are relative to it.
To test your own app in another module, copy the driver into the root of that module, and point `-pkg` at the guest package there.
The driver imports `github.com/hajimehoshi/ebiten/v2/exp/vmhost`, so the host and the guest must resolve to the same Ebitengine version.
Use the `go.mod` or the `replace` directives of your module to keep them aligned.

The driver must be in the module that contains the guest, because `go run` does not build a directory outside the main module.
Thus, every step copies it into a scratch directory there.
A directory with a `.` prefix stays out of `go build ./...`. Remove it when you finish.

### 1. No input: capture a frame

Copy the driver, and run it unchanged against any guest package:

```bash
mkdir -p .vmdriver && cp <skill-root>/scripts/headless-driver/main.go .vmdriver/
go run ./.vmdriver \
  -pkg ./examples/rotate -ticks 60 -out /tmp/frame.png
```

The flags are `-pkg` (the guest package), `-ticks` (how many ticks to run before it dumps the frame and exits), and `-out` (the PNG path).
`-w`/`-h` set the logical screen size, and the default is 320×240.
In a restricted sandbox, `go run` can need a writable `GOCACHE`, or approval to use the normal Go build cache.

### 2. With input: script the ticks

Copy the driver to a scratch directory, edit the `INPUT SCRIPT` block in `Update`, then run the copy:

```bash
mkdir -p .vmdriver && cp <skill-root>/scripts/headless-driver/main.go .vmdriver/
# edit .vmdriver/main.go — the INPUT SCRIPT block in Update
go run ./.vmdriver -pkg ./examples/paint -ticks 120 -out /tmp/frame.png
```

These are the injectors on `*vmhost.GuestSession`.
The guest observes injected state at the **next** `AdvanceTicks`, and the state stays until you change it.
Thus, the timing comes from *where* you inject in the run. Split the run into `AdvanceTicks` segments, and inject between them:

```go
// keyboard
d.guest.PressKey(ebiten.KeyArrowRight)
d.guest.ReleaseKey(ebiten.KeyArrowRight)
d.guest.TypeRune('a')                 // a typed character (input chars)
// mouse — coordinates are outside-screen device-independent pixels
d.guest.MoveCursor(160, 120)
d.guest.PressMouseButton(ebiten.MouseButtonLeft)
d.guest.ReleaseMouseButton(ebiten.MouseButtonLeft)
d.guest.ScrollWheel(0, -1)
// touch — id, then device-independent pixels
d.guest.PressTouch(0, 100, 100)
d.guest.MoveTouch(0, 120, 100)
d.guest.ReleaseTouch(0)
// gamepads — full snapshot each call; see vmhost.GamepadState
d.guest.UpdateGamepads([]vmhost.GamepadState{ /* ... */ })
// gamepad touchpad — TouchSurfaces lists each surface's current touches,
// positions in [0, 1] with (0, 0) at the top left
d.guest.UpdateGamepads([]vmhost.GamepadState{{
	ID:   0,
	Name: "Pad",
	TouchSurfaces: [][]vmhost.GamepadTouchState{
		{{ID: 1, X: 0.25, Y: 0.5}},
	},
}})
```

The `ID` of a gamepad touch identifies it across `UpdateGamepads` calls.
A touch with the same ID on the same surface in the previous call is the same touch, and it keeps its `ebiten.GamepadTouchID` in the guest.
Any other touch is a new touch.
To lift a finger, send a snapshot without it. To put down a new finger, use an ID that the previous snapshot did not have.
The guest tracks each call as a snapshot. Thus, a touch that is not in a call ends, even if no tick runs before the next call.
A surface tracks a maximum of 16 touches at the same time.

Tick counts are in the time units of the guest.
To convert seconds of app time into `AdvanceTicks` counts, read [Ticks and TPS](#ticks-and-tps).

The example below is an `INPUT SCRIPT` block that uses `-ticks` as the total run length.
It lets the app settle for 30 ticks, holds a click for one tick, then runs the remaining ticks.
For shorter total runs, decrease the settle count first.

```go
d.guest.AdvanceTicks(30) // let the app settle
d.guest.MoveCursor(160, 120)
d.guest.PressMouseButton(ebiten.MouseButtonLeft)
d.guest.AdvanceTicks(1)  // one tick with the button held
d.guest.ReleaseMouseButton(ebiten.MouseButtonLeft)
if rest := *ticks - 31; rest > 0 {
	d.guest.AdvanceTicks(rest)
}
```

### 3. Many states: take a snapshot of each one

The `snapshot(i)` method of the driver renders the *current* state of the guest.
It writes the frame to a numbered PNG that it derives from `-out` (`frame.png` → `frame_00.png`, `frame_01.png`, …).
Call it between input segments in the `INPUT SCRIPT` block, to move the app through N states and capture each one.
In practice, this is the pattern with the highest value.
For example, click through each page of a multi-page app, and compare all of them with golden images:

```go
d.guest.AdvanceTicks(30) // let the app settle
for page := 0; page < pageCount; page++ {
	if page > 0 {
		d.guest.MoveCursor(nextButtonX, nextButtonY) // click "next page"
		d.guest.PressMouseButton(ebiten.MouseButtonLeft)
		d.guest.AdvanceTicks(1)
		d.guest.ReleaseMouseButton(ebiten.MouseButtonLeft)
		d.guest.AdvanceTicks(30)
	}
	if err := d.snapshot(page); err != nil {
		return err
	}
}
```

Each `snapshot` runs the `AdvanceFrame` / `WaitFrame` / `CompositeFrame` sequence itself, so the numbered PNGs are exact frames.
The driver still writes the final `-out` frame at the end of `Update`.

### 4. Examine the output

Examine the PNG with the available image-viewing tool.
For a programmatic assertion, read pixels in `Update` after `CompositeFrame`, and compare them.
`d.screen.ReadPixels(buf)` gives premultiplied-alpha RGBA, with 4 bytes for each pixel.

Input coordinates and `-w`/`-h` are logical device-independent pixels. But `d.screen` and the PNG are physical pixels (`logical × DeviceScaleFactor`).
For example, a 320×240 logical screen can give a 640×480 PNG on a 2x display.
Use `b := d.screen.Bounds()` for the dimensions of an assertion. The centre pixel of that physical `w*h` image is at `4*((h/2)*w + w/2)`.

For a golden check, dump the frame once and look at it. On later runs, compare bytes against the saved PNG.
For the pitfalls, read [Verifying a run](#verifying-a-run).

## Verifying a run

Use the **presence of the output PNG** (or the final `wrote frame` log line of the driver) as the measure of success.
Never use the exit status that you observe through a pipe.
Do not pipe the output of the driver through `tail -1`, and do not send it to `/dev/null`.
When the driver fails, these discard its real one-line error (the `fmt.Fprintln` in `main`).
Then only the generic `exit status 1` of `go run` stays, with nothing to diagnose.
Save the full output to a log file, and read it on failure:

```bash
go run ./.vmdriver -pkg ./examples/paint -ticks 120 -out /tmp/frame.png \
  > /tmp/run.log 2>&1 || cat /tmp/run.log
```

When you compare captures byte for byte with `cmp -s`, first check that both files exist.
A missing file, from a capture that failed silently, also shows as a difference, and it looks like a pixel regression.

### Golden baselines across a code change

To compare before and after a code change, capture the baseline from the committed state.
Extract it with `git show <commit>:<file>`, or use a temporary commit.
Do **not** use `git stash` round-trips. The stash list is global to the repository and shared across worktrees.
A stray `git stash pop` can take an unrelated stash entry that belongs to the user.

## How the driver drives the guest

The whole run occurs in one host `Update`:

```go
d.guest.AdvanceTicks(*ticks) // run every tick back-to-back, no real-time pacing
d.guest.AdvanceFrame()       // request the final frame
d.guest.WaitFrame()          // block until all queued ticks have run and it is rendered
d.guest.CompositeFrame()     // composite it into the host-owned screen image; check the bool in assertions
```

`AdvanceTicks(*ticks)` queues all the ticks at once.
Then `WaitFrame` blocks until they all run and the final frame is rendered, so one wait covers all of them.
That order keeps the capture deterministic, and the screen shows exactly the end of the run.
Only the one frame is rendered, because a tick forwards no rendering. Only a frame does.

**This compresses wall-clock time**, which is the purpose of the VM.
The host does not pace the guest to its approximate 60 TPS. Thus, a 1000-tick run finishes almost instantly, not in approximately 16 real seconds.
To capture intermediate frames or pace input manually, interleave the calls instead: `AdvanceTicks(n)`, `AdvanceFrame`, `WaitFrame`, `CompositeFrame`, and repeat.
`PendingTicks` and `WaitTicks` track the backlog. Ticks coalesce, so a large queue of ticks costs little.

`guest.Err()` becomes non-nil when the guest terminates, crashes, or times out.
A guest that panics prints its stack to stderr, and the driver stops.
The driver also sets a deadline to accept the guest connection.
Thus, a guest that never connects to the host fails, and it does not hang indefinitely.

## Ticks and TPS

A tick is one guest `Update` call, and `AdvanceTicks(n)` runs exactly n of them.
The TPS of the guest never throttles or scales this. The host alone chooses how many ticks to run, and at which real-time rate, if any.

TPS is important as a unit conversion.
The game logic of the guest assumes that `Update` runs TPS times in each second of real time, so its timers, animations, and cooldowns count in those units.
`d.guest.RequestedTPS()` reports what the game requested through `ebiten.SetTPS`. This is the standard 60 until the game changes it.
To simulate a duration of app time, multiply the seconds by that value.
One second in a 30-TPS game is `AdvanceTicks(30)`, not 60.

`RequestedTPS` can also return `ebiten.SyncWithFPS` (-1).
This means that the game ties its ticks to rendered frames, not to a fixed rate.
Then there is no conversion from seconds to ticks. Treat a tick as a frame, and choose counts from what you observe in the app.

## Observing audio

The guest plays no local audio.
Instead, the host gets each audio stream that the guest starts through the `OnAudioStream` handler, which the driver registers when it makes the session.
Each stream is a separate `*vmhost.GuestAudioStream` that is **not mixed**.
The driver already connects this handler. `d.onAudioStream` collects the streams.
`d.appendAudioStreams(nil)` gives back the streams that are still open, and it drops any that the guest closed.

The audio methods are goroutine-safe, and they are not bound to a frame (unlike `CompositeFrame`/`Close`), so examine them anywhere.
The host pulls sample data from the guest on demand.
Put this into `Update` after the ticks run, for example after `WaitFrame`, so that the host has the streams that the run started:

```go
rate := d.guest.AudioSampleRate()             // per-channel samples/sec; 0 until audio plays
for i, s := range d.appendAudioStreams(nil) { // one entry per still-open guest player
    slog.Info("guest audio player", "i", i,
        "playing", s.IsPlaying(), "volume", s.Volume(), "position", s.Position())
    // Raw PCM: 32-bit little-endian floats, two interleaved channels, at `rate`.
    // Read pulls on demand; volume is reported but NOT applied to these samples.
    buf := make([]byte, 4096)
    n, _ := s.Read(buf) // 0 bytes while paused; io.EOF once the guest closes/ends the source
    slog.Info("read PCM", "bytes", n, "rate", rate)
}
```

`OnAudioStream` fires once for each stream, when the guest starts it.
It fires during `AdvanceTicks` and `WaitTicks`, on the goroutine that calls them.
The handler of the driver only keeps the handle. Read the samples from `Update`, as above.
A stream stays valid after `io.EOF`, because a seek and replay gives more samples.
When the guest closes its player, `IsClosed()` returns true, and `Read` reports `io.EOF` permanently.
Then `appendAudioStreams` drops the stream, and it returns only the streams of the guest that are still open.
To *hear* the stream and not only examine it, give the stream to a host `audio.Player` as its source.
For an example, read [examples/vm/main.go](https://github.com/hajimehoshi/ebiten/blob/345100b0e4b75ed7e06d2a1cd84571814a5e6140/examples/vm/main.go).

## Gotchas

- **The host and the guest must use the same ebiten version.** The protocol between host and guest is locked to a version.
  The driver builds the guest in your current module, so the versions agree automatically.
  A guest built against a different ebiten version, such as a prebuilt binary, fails the handshake.
- **The host still needs a display or a graphics context.** It is *windowless*, not *displayless*.
  On macOS, it works from a normal shell.
  On bare headless Linux CI, you still need Xvfb or an EGL setup to make the hidden window. The guest needs neither.
- **Call `SetOutsideScreen` before the first `AdvanceTicks`.** The image is in **physical** pixels (logical size × `DeviceScaleFactor`).
  The driver does this. If you change the screen size, keep it.
- **Call `GuestSession.Close` from the host frame.** The driver closes the guest inside `Update`, after it dumps the frame.
  If you copy the template, keep that structure. `cmd.Wait` can run after `ebiten.RunGame` returns.
  When the host disappears, the `RunGame` of the closed guest ends without an error, so the guest exits with code 0 on its own.
  The driver waits for it and does not kill it, and it treats a non-zero exit as a real guest crash.
- **Launches sometimes fail at random.** Runs one after the other sometimes fail on the first attempt, and an identical second run succeeds.
  The root cause is not known. It can be socket or handshake timing. Try once more before you debug.
- **Wall-clock time is not deterministic.** The tick *count* is exact, but code that uses `time.Now()` still sees real time between ticks.
- **`exp/vmhost` is experimental.** Its API can change.
- **The length of a Unix socket path is limited** (approximately 104 bytes on macOS), so the driver keeps its socket in a short temporary directory.
  Unix sockets work on every desktop target, Windows included.
  If a filesystem socket is not convenient, a `tcp` loopback listener (`127.0.0.1:0`) is an equivalent alternative.

## Alternative in the Ebitengine repository: a Go test

To run an app as a guest from a `go test` instead of a standalone driver, copy the structure of the end-to-end tests of the package:
[exp/vmhost/guest_test.go](https://github.com/hajimehoshi/ebiten/blob/345100b0e4b75ed7e06d2a1cd84571814a5e6140/exp/vmhost/guest_test.go) (the `startGuest` / `tickAndFrame` helpers)
and [exp/vmhost/readpixels_test.go](https://github.com/hajimehoshi/ebiten/blob/345100b0e4b75ed7e06d2a1cd84571814a5e6140/exp/vmhost/readpixels_test.go).
These tests use `MainWithRunLoop` from `internal/testing`, which only code inside the ebiten module can import.
