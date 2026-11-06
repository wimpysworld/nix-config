# Trigger scenarios

These are source-level description checks, not claims of live client discovery or measured design quality.

| User message | Expected behaviour |
| --- | --- |
| "Build a landing page for this project." | Load `frontend-design` and `web-interface-guidelines`, preserve project conventions, and require rendered verification before delivery. |
| "Polish this µCSS page without changing its brand." | Load `frontend-design`, `mucss`, and `web-interface-guidelines`. Correct local defects without replacing the identity. |
| "This dashboard has too many labels and weak contrast." | Load `frontend-design`. Review information roles and measure rendered contrast in every supported theme. |
| "Suggest a type hierarchy, but do not build anything." | Load `frontend-design`. Give advice without claiming rendered verification or requiring a running page. |
| "Build the page, but the browser tool is unavailable." | Complete independent source work and report the browser blocker. Mark the result unverified and not review-ready. |
| "Fix the API retry backoff." | Ignore `frontend-design` because the task has no interface-design scope. |
| "Design a Ratatui terminal dashboard." | Defer to `tui-design`. |
| "Draw an architecture diagram." | Defer to `diagram-design`. |

Recheck these boundaries after description changes. Verify all four generated client forms separately through the repository's composition checks.
