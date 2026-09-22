# Themes and behaviour

## Brand overrides

Use the selected theme as the starting point. Put small overrides after µCSS rather than editing the framework file.
The framework uses `--mu-*` custom properties, not `--pico-*`.

This original example changes the base radius without changing the colour palette:

```css
:root {
  --mu-border-radius: 0.5rem;
}
```

Not every component uses this token. For example, `.btn` declares its own radius in the reference version.
Inspect the selected component before expecting a global variable to change it.
For brand colours, inspect each role's text, background, inverse, hover, and focus properties together.
Check selector specificity and mode-specific declarations in the compiled CSS before choosing an override selector.
Sources: [compiled CSS](https://github.com/Digicreon/muCSS/blob/f42cabdda91353d782bca0ed78d33e2a62396b88/dist/mu.css), [button CSS](https://github.com/Digicreon/muCSS/blob/f42cabdda91353d782bca0ed78d33e2a62396b88/css/mu.component.button.css).

## Colour mode

| Requirement | Root element |
| --- | --- |
| Follow the system | `<html lang="en">` |
| Force light | `<html lang="en" data-theme="light">` |
| Force dark | `<html lang="en" data-theme="dark">` |

Use the page's actual language. For system mode, remove `data-theme` rather than setting it to `auto`.
If the brief requires a mode selector, define its behaviour and persistence separately from the stylesheet.
A stylesheet does not implement a control that changes or remembers the attribute.
Source: [dark-mode rules](https://github.com/Digicreon/muCSS/blob/f42cabdda91353d782bca0ed78d33e2a62396b88/dist/mu.css).

## Interaction caveats

Prefer visible navigation links for a short landing page. Allow project CSS to wrap the links when necessary.
The upstream mobile pattern uses a hidden checkbox and a label. Its CSS sets `.navbar-toggle` to `display: none`.
Do not describe this pattern as keyboard-accessible by default. Check keyboard operation before adopting it.
If a collapsed menu is necessary, use a tested control with appropriate state and focus behaviour.
Source: [navigation CSS](https://github.com/Digicreon/muCSS/blob/f42cabdda91353d782bca0ed78d33e2a62396b88/css/mu.component.nav.css).

For a required modal, use native `dialog` behaviour rather than styling an always-visible overlay.
Calls to `showModal()` and `close()` require JavaScript. A CSS-only dependency does not remove the need to implement behaviour.
Apply `web-interface-guidelines` to focus, dismissal, and return focus instead of assuming that the theme handles these requirements.

The hero and navigation use `color-mix()`. Navigation also uses `:has()`.
Confirm support in the project's browser targets before relying on those effects.
When a fallback is necessary, preserve readable content and usable controls before matching the decorative treatment.
A static source check does not establish that these features work in the target browsers.
