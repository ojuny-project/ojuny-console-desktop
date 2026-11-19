{
  lib,
  stdenv,
  makeWrapper,
  wrapGAppsHook3,
  gobject-introspection,
  python3,
  gtk4,
  libadwaita,
  libmanette,
  libgudev,
  pango,
  nix-settings-gui,
}:
let
  python = python3.withPackages (packages: [ packages.pygobject3 ]);

  typelibPath = lib.makeSearchPath "lib/girepository-1.0" [
    gtk4
    libadwaita
    libmanette
    libgudev
    pango
  ];
in
stdenv.mkDerivation {
  pname = "ojuny-console-settings";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [
    gobject-introspection
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    gtk4
    libadwaita
    libmanette
    libgudev
    pango
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/ojuny-console-settings" "$out/bin" "$out/share/applications"
    cp -r ojuny_console_settings "$out/lib/ojuny-console-settings/"

    makeWrapper ${python}/bin/python3 "$out/bin/ojuny-console-settings" \
      --add-flags "-m ojuny_console_settings" \
      --prefix PYTHONPATH : "$out/lib/ojuny-console-settings" \
      --prefix GI_TYPELIB_PATH : "${typelibPath}" \
      --set OJUNY_CONSOLE_SETTINGS_BACKEND "${nix-settings-gui}/bin/nix-settings-backend"

    install -Dm644 org.ojuny.ConsoleSettings.desktop \
      "$out/share/applications/org.ojuny.ConsoleSettings.desktop"

    runHook postInstall
  '';

  meta = {
    description = "Controller-first settings frontend for Ojuny Console";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "ojuny-console-settings";
  };
}
