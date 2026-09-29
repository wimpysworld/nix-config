{
  lib,
  fetchFromGitLab,
  rustPlatform,
  pkg-config,
  wrapGAppsHook4,
  gtk4,
  gtksourceview5,
  libadwaita,
  libspelling,
  glib-networking,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "manuscript";
  version = "1.5.2";

  src = fetchFromGitLab {
    owner = "ilshat-apps";
    repo = "manuscript";
    tag = "v${finalAttrs.version}";
    hash = "sha256-qKHn7BVbrWAltzX6FxiYXu5oO6wri0AzxiLAi3Ti0WM=";
  };

  cargoHash = "sha256-3A0L098IdQN+3M0+jBW6dbsRuBkf7rTOti9r7Ow6HYU=";

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook4
  ];

  buildInputs = [
    gtk4
    gtksourceview5
    libadwaita
    libspelling
    glib-networking
  ];

  postInstall = ''
    install -Dm644 data/io.gitlab.ilshat_apps.manuscript.desktop \
      $out/share/applications/io.gitlab.ilshat_apps.manuscript.desktop
    install -Dm644 data/io.gitlab.ilshat_apps.manuscript.metainfo.xml \
      $out/share/metainfo/io.gitlab.ilshat_apps.manuscript.metainfo.xml
    install -Dm644 data/icons/hicolor/scalable/apps/io.gitlab.ilshat_apps.manuscript.svg \
      $out/share/icons/hicolor/scalable/apps/io.gitlab.ilshat_apps.manuscript.svg
  '';

  meta = {
    description = "GNOME Markdown reader and editor";
    homepage = "https://gitlab.com/ilshat-apps/manuscript";
    changelog = "https://gitlab.com/ilshat-apps/manuscript/-/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "manuscript";
    platforms = lib.platforms.linux;
  };
})
