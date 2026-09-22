# µCSS Landing Pages

Build static project landing pages with Digicreon µCSS while preserving the site's existing generator and asset pipeline.

## Establish the brief

1. Read the project instructions and the current page sources.
2. Identify the audience, the project's main benefit, and the primary action: install, download, or read the documentation.
3. Confirm the repository, documentation, release, licence, and contribution links from project evidence.
4. Resolve missing brand assets, deployment paths, or content requirements before making assumptions that change the design.
5. Load `web-interface-guidelines` for general interface quality and accessibility checks. Do not replace its checks with framework claims.

## Preserve the integration

- Confirm that the framework is [Digicreon µCSS](https://mucss.org/about), package `@digicreon/mucss`, not a similarly named library.
- Identify the installed version, selected stylesheet, custom CSS, templates, and generator's output directory.
- Edit templates and source assets, not generated HTML or installed packages.
- Keep the existing version and asset route unless the user requests a change.
- Read [assets and versions](references/assets.md) before adding or changing a stylesheet.
- Do not install packages or tools, download framework assets, build upstream sources, or activate configuration without separate authority.
- PHP, npm, Temma, and µJS are not prerequisites for a static page that uses a prebuilt µCSS stylesheet.

## Compose the page

- Put the project promise and primary action first, followed by evidence that helps the visitor decide.
- Select useful sections: a working example, key capabilities, installation, documentation, and contribution routes.
- Use project facts rather than invented download counts, testimonials, badges, or release claims.
- Keep command examples consistent with the project's supported installation method.
- Use [layout and components](references/layout.md) for µCSS-specific markup and responsive rules.
- Use semantic HTML first. Add framework classes only where they provide the required presentation.
- Do not assume that PicoCSS, Bootstrap, or Tailwind class names work in µCSS.

## Apply the brand and behaviour

- Keep brand overrides in the project's stylesheet after µCSS. Read [themes and behaviour](references/themes.md) before changing tokens or controls.
- Prefer the existing theme and system colour preference unless the brief requires another choice.
- Check each component's own breakpoints rather than treating the grid thresholds as global rules.
- Prefer native links and disclosure controls over custom navigation, modals, or copied demo scripts.
- Keep essential content usable without optional JavaScript. Add behaviour only for a required interaction.

## Check the generated page

1. Use the project's existing build and validation commands within the authorised scope.
2. Inspect the generated HTML, resolved stylesheet URLs, and emitted assets at the actual deployment base path.
3. Check that documentation, release, source, licence, and section links resolve to the intended destinations.
4. Apply `web-interface-guidelines` to the output, including each theme and interactive state that the page supports.
5. With authorised browser tools, check narrow layouts and both sides of relevant breakpoints against the actual stylesheet.
6. Test required `:has()` and `color-mix()` behaviour in the project's supported browsers, or supply a suitable fallback.
7. Report changed sources, version and theme choices, checks performed, and checks that still need a browser.

Do not claim rendered, keyboard, contrast, or browser compatibility results from source inspection alone.
