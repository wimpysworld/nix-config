# Assets and versions

## Reference baseline

These original notes use [Digicreon/muCSS revision f42cabdda91353d782bca0ed78d33e2a62396b88](https://github.com/Digicreon/muCSS/tree/f42cabdda91353d782bca0ed78d33e2a62396b88) as a reference baseline.
Its [package metadata](https://github.com/Digicreon/muCSS/blob/f42cabdda91353d782bca0ed78d33e2a62396b88/package.json) declares `@digicreon/mucss` version `1.4.9`.
This baseline is not an instruction to upgrade a project.

The [official documentation](https://mucss.org/documentation) describes the framework. For exact behaviour, inspect the CSS shipped by the project's selected version.
The [installation page](https://mucss.org/documentation/installation) includes an older `1.4.6` SRI example. Do not reuse its version or hash for another asset.

## Choose the existing route

Each `dist/mu.{theme}.css` file is a complete stylesheet. `dist/mu.css` is the Azure alias, not a separate base layer.
Load one theme file, followed by project overrides. Do not add PicoCSS alongside it.
See the [distribution description](https://github.com/Digicreon/muCSS/blob/f42cabdda91353d782bca0ed78d33e2a62396b88/README.md).

| Existing setup | Integration |
| --- | --- |
| Static assets in the repository | Preserve the selected stylesheet and the generator's copy or fingerprint step. |
| npm dependency | Keep the lockfile version and existing CSS import or asset-copy mechanism. npm is optional. |
| CDN stylesheet | Keep the approved provider and version policy. For a new production URL, select an explicit approved version. |

Do not expose `node_modules` as a deployment requirement. Check that the generator emits the chosen stylesheet into the public output.
For CDN use, check the project's CSP, offline requirements, and external-request policy before changing the route.
If SRI is required, verify the hash against the exact served bytes, version, and theme.

This independent example assumes that both assets already exist beside the generated page:

```html
<link rel="stylesheet" href="assets/mu.azure.css">
<link rel="stylesheet" href="assets/project.css">
```

Replace the example paths with the generator's asset helper or deployment-aware paths. Nested pages and subpath hosting need separate checks.
Do not paste this fragment into a layout that already loads µCSS.

## Source and licence boundary

This skill contains original guidance and small original examples, not framework assets or an adapted PicoCSS skill.
Source links record technical evidence, not ownership or a licence grant for this skill.
Do not copy upstream prose, scripts, templates, or stylesheets into the skill.
If separately authorised work needs substantial upstream content, inspect its licence and preserve the applicable copyright and MIT notice.
Do not build upstream sources or install PHP merely to publish a page that uses a prebuilt stylesheet.
