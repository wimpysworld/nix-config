(() => {
  const storageKey = "tailor-theme";
  const root = document.documentElement;
  const systemTheme = window.matchMedia("(prefers-color-scheme: dark)");
  const themeColours = document.querySelectorAll('meta[name="theme-color"]');
  const backgrounds = { light: "#fff", dark: "rgb(19, 22.5, 30.5)" };
  let preference = "system";

  try {
    const saved = localStorage.getItem(storageKey);
    if (saved === "light" || saved === "dark") preference = saved;
  } catch {
    // Theme selection still works when browser storage is unavailable.
  }

  function currentTheme() {
    if (preference !== "system") return preference;
    return systemTheme.matches ? "dark" : "light";
  }

  function applyTheme() {
    if (preference === "system") root.removeAttribute("data-theme");
    else root.setAttribute("data-theme", preference);

    themeColours.forEach((meta) => {
      const mediaTheme = meta.media.includes("dark") ? "dark" : "light";
      const colourTheme = preference === "system" ? mediaTheme : preference;
      meta.content = backgrounds[colourTheme];
    });
  }

  // Apply a saved choice before stylesheets load to avoid a theme flash.
  applyTheme();

  document.addEventListener("DOMContentLoaded", () => {
    const year = document.getElementById("copyright-year");
    if (year) year.textContent = new Date().getFullYear();

    const picker = document.getElementById("theme-picker");
    const select = document.getElementById("theme-select");
    if (!picker || !select) return;

    function updateControls() {
      const current = currentTheme();
      select.value = preference;
      document
        .getElementById("theme-sun")
        .toggleAttribute("hidden", current !== "light");
      document
        .getElementById("theme-moon")
        .toggleAttribute("hidden", current !== "dark");
    }

    function chooseTheme(choice) {
      preference = choice;
      applyTheme();
      updateControls();
      try {
        if (preference === "system") localStorage.removeItem(storageKey);
        else localStorage.setItem(storageKey, preference);
      } catch {
        // Keep the current choice for this page when storage is unavailable.
      }
    }

    updateControls();
    picker.hidden = false;
    select.addEventListener("change", () => chooseTheme(select.value));
    systemTheme.addEventListener("change", () => {
      if (preference === "system") {
        applyTheme();
        updateControls();
      }
    });
  });
})();
