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
  version = "1.6.2";

  src = fetchFromGitLab {
    owner = "ilshat-apps";
    repo = "manuscript";
    tag = "v${finalAttrs.version}";
    hash = "sha256-yHZlmYZhuKXV+YVQYlkm8fJqh4KGWV/eNPfUW1k2AvQ=";
  };

  cargoHash = "sha256-rF49d/NMdvK57FVX4M0ETkcYbzzvSV2Fg5FF+sB5l8Q=";

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
