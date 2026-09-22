# Layout and components

Use these independent fragments inside the project's existing document layout. Replace the sample content with verified project facts.

## Hero and action

Place the full-width hero outside a width-limited container. Put the content container inside the hero.

```html
<section class="hero hero-primary" aria-labelledby="project-title">
  <div class="container">
    <h1 id="project-title">Archive Map</h1>
    <p>Find the files that belong to each release.</p>
    <div class="hero-actions">
      <a class="btn btn-primary" href="#quick-start">Read the quick start</a>
    </div>
  </div>
</section>
```

Keep the link as a link. `.btn` changes its appearance without requiring `role="button"`.
The destination needs a matching `id="quick-start"` in the actual page.
The hero changes primary action colours, so check the action inside the hero rather than in isolation.
Sources: [hero CSS](https://github.com/Digicreon/muCSS/blob/f42cabdda91353d782bca0ed78d33e2a62396b88/css/mu.component.hero.css), [button CSS](https://github.com/Digicreon/muCSS/blob/f42cabdda91353d782bca0ed78d33e2a62396b88/css/mu.component.button.css).

## Columns and cards

Use `.row` around column wrappers. Keep card styling on `article`, not on a generic `.card` container.

```html
<div class="row">
  <div class="col-12 col-md-6 col-lg-4">
    <article class="card-primary">
      <h3>Release index</h3>
      <p>Browse the files for a selected release.</p>
    </article>
  </div>
</div>
```

This example assumes an enclosing section with an `h2`. Add sibling columns only for real content.
A column spans the row initially, half the row from `768px`, and one third from `1024px`.
Source: [grid CSS](https://github.com/Digicreon/muCSS/blob/f42cabdda91353d782bca0ed78d33e2a62396b88/css/mu.grid.css).

| Prefix | Minimum viewport width |
| --- | --- |
| `col-` | `0` |
| `col-sm-` | `576px` |
| `col-md-` | `768px` |
| `col-lg-` | `1024px` |
| `col-xl-` | `1280px` |
| `col-xxl-` | `1536px` |

Rows use negative horizontal margins. Check their surrounding padding before adding custom gaps or overflow fixes.
The [card CSS](https://github.com/Digicreon/muCSS/blob/f42cabdda91353d782bca0ed78d33e2a62396b88/css/mu.component.card.css) styles `article[class*="card-"]` and its direct `header` and `footer` children.
Check text contrast on coloured cards. A role class is not proof of suitable contrast for all child content.

## Native disclosure

```html
<div class="accordion">
  <details>
    <summary>Where are release notes?</summary>
    <p>Each release links to its changes in the project repository.</p>
  </details>
</div>
```

Keep `details` directly inside `.accordion` and `summary` directly inside `details`.
Do not add JavaScript that duplicates native disclosure behaviour.
Source: [accordion CSS](https://github.com/Digicreon/muCSS/blob/f42cabdda91353d782bca0ed78d33e2a62396b88/css/mu.component.accordion.css).

## Responsive differences

The hero uses `max-width: 640px` and `min-width: 960px`. The mobile navigation rules use `max-width: 639px`.
These are not the grid thresholds.

Container descriptions can differ from the compiled stylesheet. At the reference revision, `.container` maximum widths are `510/700/950/1200/1450px` at the five grid thresholds.
Use the project's actual [compiled CSS](https://github.com/Digicreon/muCSS/blob/f42cabdda91353d782bca0ed78d33e2a62396b88/dist/mu.css) when a documentation table disagrees.
Do not substitute Bootstrap container widths or assume that `.container-fluid` has the same width limits.
