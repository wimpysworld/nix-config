# TypeScript and JavaScript ecosystem

Prefer Ink for a React-based TUI and Clack for a setup wizard.
Choose between output-only CLI tools and full TUIs before selecting a renderer.
All reference paths are relative to the skill root.

## Contents

- [Quick recommendation](#quick-recommendation)
- [Ink](#ink)
- [Lifecycle and terminal handoff](#lifecycle-and-terminal-handoff)
- [Primitives](#primitives)
- [Layout](#layout)
- [Hooks](#hooks)
- [ink-ui](#ink-ui)
- [Testing](#testing)
- [Debugging](#debugging)
- [Pastel](#pastel)
- [Strengths and weaknesses](#strengths-and-weaknesses)
- [Ink pitfalls](#ink-pitfalls)
- [Clack](#clack)
- [Inquirer](#inquirer)
- [Colour libraries](#colour-libraries)
- [Other utilities](#other-utilities)
- [Argument parsers](#argument-parsers)
- [OpenTUI](#opentui)
- [Legacy renderers](#legacy-renderers)
- [Apps to study](#apps-to-study)
- [Shared pitfalls](#shared-pitfalls)
- [Stacks by project type](#stacks-by-project-type)

## Quick recommendation

| Need | Use |
| --- | --- |
| Full TUI | Ink |
| Wizard prompts | `@clack/prompts` |
| Complex questions | `@inquirer/prompts` |
| One spinner | ora |
| Hierarchical tasks | listr2 |
| General argument parsing | commander |
| Extensive argument validation | yargs |
| Plugin CLI | oclif |
| TypeScript-first parsing | citty |
| Small parser | cac, about 7K, or `node:util.parseArgs` |
| Fast colour formatting | picocolors |
| Chainable colour API | chalk |
| Boxed message | boxen |
| High-frequency graphics | OpenTUI, with v0.x stability limits |
| Terminal images | terminal-kit |

Default full-TUI stack: Ink + `@inkjs/ui` + zustand + commander + ink-testing-library.
Check the input-test limitation below before selecting test methods.

## Ink

`vadimdemedes/ink` is a React renderer for terminal nodes: `ink-root`, `ink-box`, and `ink-text`.
It uses `react-reconciler`, Yoga layout, frame buffers, and ANSI differences in a buffered write.
The upstream baseline is Ink 7.1.x in mid-2026, which requires Node ≥ 22 and React 19.
For Node 20 LTS, use Ink 6.

```tsx
import React, {useState} from 'react';
import {render, Text, Box, useInput, useApp} from 'ink';

const App = () => {
  const [n, setN] = useState(0);
  const {exit} = useApp();

  useInput((input, key) => {
    if (key.upArrow) setN(c => c + 1);
    if (key.downArrow) setN(c => c - 1);
    if (input === 'q') exit();
  });

  return (
    <Box borderStyle="round" padding={1}>
      <Text color="green">Counter: {n}</Text>
    </Box>
  );
};

render(<App />);
```

## Lifecycle and terminal handoff

Keep permanent unmount separate from temporary suspension.
Put process signal policy at the render boundary.

| Boundary | Ink 7 contract |
| --- | --- |
| Normal exit | Use `useApp().exit(...)` inside the tree, or the render handle's `unmount()` outside it. Await `waitUntilExit()` before final output or termination. |
| Signals | `exitOnCtrlC` handles raw input bytes, not OS SIGTERM. Register required signals once, unmount, await cleanup, set status, and remove listeners. |
| Interactive child | Use `await suspendTerminal(async () => runChild())`. It pauses input/rendering, restores modes, invokes the callback, and re-enters with a full redraw in `finally`. |
| Manual suspension | Always `await suspension.resume()` in `finally`, or use `await using`. Do not unmount. |
| Unix job control | If required, send SIGTSTP inside `suspendTerminal`. Its resume path restores the UI. Provide a different action on Windows. |

Do not call `process.exit()` before pending terminal writes finish.
The suspension callback also runs without an interactive TTY.
After child execution, reload changed data. Redraw preserves existing React state.
Only one suspension can own the terminal. A second overlapping suspension is an error.
Centralise suspension ownership.
See the [tagged suspension API](https://github.com/vadimdemedes/ink/blob/v7.1.1/readme.md#suspendterminalcallback) for callback, manual, non-interactive, and nested use.

## Primitives

| Component | Contract |
| --- | --- |
| `<Text>` | Contains strings. Supports `color`, `backgroundColor`, `bold`, `italic`, `underline`, `inverse`, `dimColor`, `wrap`, `strikethrough`. |
| `<Box>` | Flex container. Supports padding, margin, borders, width/height, flex properties, alignment, gap, and display. |
| `<Newline>` | Vertical spacing |
| `<Spacer>` | Flexible space |
| `<Static>` | Permanent append-only output above the live UI. Does not re-render completed items. |
| `<Transform>` | Transforms rendered child strings, for gradients, OSC 8 links, or custom effects |

Strings directly inside `<Box>` throw. Wrap them in `<Text>`.
Box padding props include `padding`, `paddingX/Y/Top/Right/Bottom/Left`.
Borders include `borderStyle`, `borderColor`, and `borderTop`/`Bottom`/`Left`/`Right`.
Flex props include `flexDirection`, `flexGrow`, `flexShrink`, `flexBasis`, `justifyContent`, and `alignItems`.
`display` accepts `'flex'` or `'none'`.
Use `<Static>` for completed Jest/Listr2-style history, not mutable selectable rows.

## Layout

Yoga is the flexbox engine also used by React Native.
Ink uses props, not CSS or `className`.
`cli-boxes` supplies `single`, `double`, `round`, `bold`, `singleDouble`, `doubleSingle`, `classic`, and custom characters.

```tsx
<Box flexDirection="column" height="100%">
  <Box borderStyle="single">
    <Text>Header</Text>
  </Box>
  <Box flexGrow={1} flexDirection="row">
    <Box width={30} borderStyle="single">
      <Text>Sidebar</Text>
    </Box>
    <Box flexGrow={1} borderStyle="single">
      <Text>Main content</Text>
    </Box>
  </Box>
</Box>
```

## Hooks

| Hook | API and purpose |
| --- | --- |
| `useInput((input, key) => ...)` | Keyboard input. Key fields include arrows, `return`, `escape`, `tab`, `ctrl`, `shift`, `meta`, `pageUp`, `pageDown`. |
| `useApp()` | `exit(errorOrResult?)`, `waitUntilRenderFlush`, `suspendTerminal` |
| `useStdin()` | `stdin`, `setRawMode`, `isRawModeSupported` |
| `useStdout()` / `useStderr()` | Writes outside the live UI |
| `useFocus({autoFocus, isActive, id})` | Tab focus |
| `useFocusManager()` | `focus(id)`, `focusNext`, `focusPrevious`, `enableFocus`, `disableFocus` |
| `useWindowSize()` | `columns`, `rows`, updated on resize |
| `usePaste(callback)` | Ink 7 bracketed paste as a single chunk |
| `useCursor()` | Real cursor placement for IME input |
| `useAnimation()` | Frame ticks with pause/resume |
| `useBoxMetrics()` | Runtime box dimensions |

Passing an `Error` to `exit` rejects `waitUntilExit()`. There is no separate error variant.
Use standard React hooks: `useState`, `useEffect`, `useReducer`, `useContext`, and `useMemo`.
For larger state, prefer Zustand. Jotai or `useReducer` + Context are alternatives.

## ink-ui

`vadimdemedes/ink-ui`, installed as `@inkjs/ui`, supplies themeable components.

| Component | Purpose |
| --- | --- |
| `<TextInput>`, `<EmailInput>`, `<PasswordInput>` | Controlled inputs |
| `<Select>`, `<MultiSelect>` | Options |
| `<ConfirmInput>` | y/n prompt |
| `<Spinner>` | Ink-native animation |
| `<ProgressBar>` | Determinate progress |
| `<Badge>` | Coloured status label |
| `<StatusMessage>` | `success`, `info`, `warning`, `error` |
| `<Alert>` | Bordered alert |

Pass theme objects at the root. Inside Ink, use `<Spinner>`, not ora.

## Testing

```tsx
import {render} from 'ink-testing-library';

const {lastFrame, rerender, stdin, frames, unmount} = render(<App />);
expect(lastFrame()).toBe('Counter: 0');
stdin.write('\u001B[A');  // up arrow
expect(lastFrame()).toBe('Counter: 1');
```

The example shows the library API, not a guarantee of working input simulation on current Ink.
`ink-testing-library` v4.0.0 dates from May 2024 and pins Ink 5/React 18 in its own development dependencies.
Its open issues include missing `useInput` callbacks after `stdin.write()`.
Frame assertions remain useful, but input simulation is unreliable on Ink ≥5.
It uses fake streams and captures text, not styles.
Ink 6.8+ also supplies synchronous `renderToString()`.

For Ink 6/7 input tests, use a custom vitest harness around Ink's own `render`, with app providers and frame helpers.
Gemini CLI uses this approach.
Add limited node-pty + strip-ansi integration tests for actual keyboard flows.
Ink and ink-testing-library are ESM-only, so prefer vitest over Jest unless existing infrastructure dictates otherwise.

## Debugging

`patchConsole` defaults to `true`.
Ink clears the live frame, writes intercepted `console.*` output above it, then redraws.
Direct `process.stdout.write` or inherited child stdio can bypass that patch and corrupt output.

Use `render(<App />, {debug: true})` to append every frame instead of updating in place.
For component inspection, install optional `react-devtools-core`, set `DEV=true`, and run `npx react-devtools` separately.
Exit the CLI manually with Ctrl+C afterwards.
Use the Components tab for tree/props inspection. Treat the Profiler tab as unsupported because Ink lacks the required reconciler flags.

Send high-volume traces through `useStderr().write()` or a file viewed with `tail -f`.
For CPU profiling, use `node --cpu-prof`.
It writes a `.cpuprofile` at exit for Chrome DevTools Performance or speedscope.

Check:

- Unmemoised children that trigger repeated Yoga layout.
- Mutable content incorrectly placed in `<Static>`.
- Completed history that unnecessarily remains in the live tree.
- Continuous animation, such as ink-spinner, that prevents idle rendering.

Ink 3 improved `<Static>` performance by almost 2x. Use it only for content that never changes.

## Pastel

`vadimdemedes/pastel` derives commands from files and validates arguments with Zod.

```
commands/
  index.tsx        // "myapp"
  create.tsx       // "myapp create"
  list.tsx         // "myapp list"
  user/
    add.tsx        // "myapp user add"
    remove.tsx     // "myapp user remove"
```

Each file exports a default React component and optional `args`/`options` Zod schemas.

## Strengths and weaknesses

| Area | Consequence |
| --- | --- |
| React and Yoga | Declarative layout, reusable hooks, state libraries, and component inspection |
| Alternate screen | Since Ink 7, `render(<App />, {alternateScreen: true})` restores prior content on exit. Older apps used fullscreen-ink. |
| Startup | React + Yoga + reconciler costs about 80-150ms cold. Bypass Ink for frequent `--version` and completion calls. |
| Modules | ESM-only since Ink 4 in March 2023. For CJS, use Ink 3 or a bundler. |
| Runtime | Ink 7 requires Node 22 and React 19. Ink 6 supports Node 20. |
| Frequent redraws | Ink 6.7+ adds synchronised updates and optional Kitty keys. Use `useDeferredValue` or debounce for streaming. |
| Accessibility | Ink 7 adds `aria-label`, `aria-hidden`, `aria-role`, and `aria-state` to Box/Text. Browser access remains stronger. |

The newer accessibility support extends the older `INK_SCREEN_READER` behaviour.

## Ink pitfalls

1. Wrap strings in `<Text>`, not direct Box children.
2. Use `nodemon --no-stdin` or `node --watch` to preserve input keys.
3. Do not combine ora and Ink renderers.
4. Ink 3+ intercepts `console.log`. Check patch bypasses before adding replacement logging logic.
5. Ink 7 reports Backspace as `key.backspace`, not the older `key.delete` workaround.

## Clack

Use `@clack/prompts` for `create-*` setup tools with a small API and linked prompt display.
The upstream baseline is stable 1.x under bombshell-dev at clack.cc.
create-vite, Svelte's `sv`, and create-t3-app use it.
create-astro uses its own `@astrojs/cli-kit` with a similar appearance. Rust's cliclack is a port.

```ts
import {intro, outro, text, confirm, select, spinner, isCancel, cancel} from '@clack/prompts';

intro('create-my-app');

const name = await text({
  message: 'Project name',
  validate: v => v.length === 0 ? 'Required' : undefined,
});
if (isCancel(name)) {
  cancel('Cancelled');
  process.exit(0);
}

const framework = await select({
  message: 'Pick a framework',
  options: [
    {value: 'react', label: 'React'},
    {value: 'vue', label: 'Vue'},
    {value: 'svelte', label: 'Svelte'},
  ],
});

const s = spinner();
s.start('Installing dependencies');
await install();
s.stop('Dependencies installed');

outro(`You're all set!`);
```

Components include `intro`/`outro`, `text`, `password`, `confirm`, `select`, `multiselect`, `groupMultiselect`, `selectKey`, `spinner`, `progress`, `taskLog`, `note`, `stream`, and `group`.
Logging methods are `log.info/.warn/.error/.success`.
Check `isCancel(value)` after each prompt to handle Ctrl+C and cleanup.

## Inquirer

Prefer `@inquirer/prompts` over the legacy monolithic `inquirer`.
Choose it for conditional questions, chained validation, custom prompt types, or internationalisation.

```ts
import {input, select, confirm, password} from '@inquirer/prompts';

const name = await input({message: 'What is your name?'});
const role = await select({
  message: 'Choose a role',
  choices: [
    {name: 'Admin', value: 'admin'},
    {name: 'User', value: 'user'},
  ],
});
```

Modular packages include `@inquirer/input`, `@inquirer/select`, `@inquirer/checkbox`, `@inquirer/confirm`, `@inquirer/password`, and `@inquirer/editor`.
Others are `@inquirer/expand`, `@inquirer/rawlist`, `@inquirer/search`, and `@inquirer/number`.
Use `@inquirer/i18n` for translations. Import only required modules.

## Colour libraries

Prefer picocolors for internal libraries and chalk for user-facing CLIs.

| Library | Size and speed | API and use |
| --- | --- | --- |
| picocolors | 7 KB, fastest single style | Functional `pc.red('hi')`. Used by PostCSS, SVGO, Stylelint, Browserslist, Babel, Prettier, Vite. |
| chalk | 101 KB, slower | Chaining and truecolour, `chalk.red.bold('hi')` |
| kleur | Small, fast | Chainable alternative |
| ansis | Small, fastest for 2+ chained styles | Chaining and truecolour |

Enforce `NO_COLOR`, non-TTY output, and explicit `--color` choices at app level.
Library behaviour varies by version.
Chalk v5+ is ESM-only. For CJS, use v4 or a bundler.

## Other utilities

| Utility | Purpose |
| --- | --- |
| ora | Single spinner, about 70+ cli-spinners styles, outside Ink |
| cli-progress | Single/multiple bars with ETA, outside Ink |
| listr2 | Concurrent tasks, retries, rollback. Renderers: `default`, `simple`, `verbose`, `silent`, `test`. |
| boxen | One-time boxed notices, also used by update-notifier |
| figlet + gradient-string | Banner text and gradients |
| terminal-link | OSC 8 links with plain URL fallback |
| string-width | Cell widths for CJK and emoji, also used by Ink |
| update-notifier | npm version checks and notices |

Use listr2's `simple` renderer for line-per-task CI output.

## Argument parsers

| Parser | Style and use |
| --- | --- |
| commander | Common default, fluent API, used by webpack, babel, vue-cli |
| yargs | Fluent API and middleware, strong validation, used by Mocha, nyc, jest |
| citty | TypeScript-first and declarative, used in UnJS/Nuxt/Nitro/unbuild |
| cac | About 7K, minimal dependencies, used by Vite |
| oclif | Class-per-command plugins, used by Heroku, Salesforce, Shopify CLI |
| `node:util.parseArgs` | Standard library, stable since Node 18, no extra dependency |

Startup cost generally rises from parseArgs/cac through commander/yargs to oclif's plugin loader.
Measure the actual binary with `hyperfine 'mycli --version'`.

```ts
import {Command} from 'commander';

const program = new Command();
program
  .name('myapp')
  .description('CLI to do things')
  .version('1.0.0');

program.command('greet')
  .description('Say hello')
  .option('-n, --name <name>', 'who to greet', 'world')
  .action(({name}) => console.log(`Hello, ${name}!`));

program.parse();
```

## OpenTUI

`anomalyco/opentui` combines TypeScript bindings and a Zig native core through C ABI.
It uses double buffers, alpha blending, scissor clipping, and a mouse hit grid.
Packages are `@opentui/core`, React's `@opentui/react`, SolidJS's `@opentui/solid`, and `@opentui/three`.
The Three.js WebGPU renderer converts 3D scenes to terminal cells.
OpenCode uses OpenTUI in production. The upstream guidance identifies terminal.shop as a planned adopter.

Choose it for animation, low-latency streams, or layouts that exceed Ink's CPU limits.
Account for v0.x changes, a smaller community, and native binaries during installation.

## Legacy renderers

| Library | Status and purpose |
| --- | --- |
| blessed | Pure-JS ncurses-style renderer with terminfo/termcap and damage buffers. Last release 0.1.81 was in September 2015. |
| neo-blessed | Maintained blessed fork |
| terminal-kit | Cursor/screen APIs, inputs, menus, truecolour/Sixel images, and a Document model |

Blessed widgets include `box`, `list`, `form`, `textbox`, `textarea`, `progressbar`, `log`, `table`, `tree`, and embedded `terminal`.
Use these for legacy maintenance, precise damage regions, or graphics needs.
For new general TUIs, prefer Ink.

## Apps to study

| App | Implementation |
| --- | --- |
| Claude Code | TypeScript, React, Ink, Yoga, Bun |
| GitHub Copilot CLI / Gemini CLI | Ink |
| Cloudflare Wrangler / Gatsby CLI / Prisma CLI | Ink |
| Shopify CLI / Linear internal CLI / Canva CLI / tap | Ink users in upstream guidance |
| OpenCode | OpenTUI |
| terminal.shop | Planned OpenTUI adoption |
| create-vite / create-astro / create-svelte | Clack-style setup interfaces |
| Listr demos | Task displays |

## Shared pitfalls

1. Check ESM/CJS compatibility for chalk v5+, ora v6+, Ink v4+, Inquirer, and Clack.
2. For CJS, pin compatible versions, bundle, or choose a compatible library such as picocolors.
3. On exit, call Ink `exit()`/`unmount()` and await `waitUntilExit()`, or use blessed `screen.destroy()`.
4. Handle OS signals separately from Ink's Ctrl+C input.
5. Detect `process.stdout.isTTY === false` and `process.env.CI` for plain output without prompts or spinners.
6. Require `process.stdin.isTTY` before raw mode.
7. Use string-width, not `.length`, for terminal cells.
8. Lazy-load commands and bypass heavy UI setup for `--version`/`--help`.
9. Do not combine competing raw-mode renderers, including Ink + ora or Ink + blessed.
10. Target Windows Terminal rather than assuming full ANSI support in older `cmd.exe`.

## Stacks by project type

| Type | Stack |
| --- | --- |
| Simple non-interactive CLI, roughly 50ms cold and 30 KB dependencies | commander + picocolors + ora |
| Setup wizard | `@clack/prompts` + picocolors + commander |
| Complex tasks | commander + `@inquirer/prompts` + listr2 + chalk + boxen + update-notifier |
| Full TUI | ink + `@inkjs/ui` + zustand + commander + ink-testing-library |
| Plugin CLI | oclif + ink + chalk + listr2 |
| Animated or performance-sensitive TUI | `@opentui/core` or `@opentui/react` |

Check startup and input tests against the installed versions before release.
