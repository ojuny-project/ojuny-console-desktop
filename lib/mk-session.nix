{ lib, pkgs }:
{
  name,
  comment,
  exec,
  desktopNames ? [ "gamescope" ],
}:
(pkgs.runCommand "${name}-session" { } ''
  mkdir -p "$out/share/wayland-sessions"
  cat > "$out/share/wayland-sessions/${name}.desktop" <<EOF
  [Desktop Entry]
  Name=Ojuny Console
  Comment=${comment}
  Exec=${exec}
  Type=Application
  DesktopNames=${lib.concatStringsSep ";" desktopNames};
  EOF
'').overrideAttrs
  (old: {
    passthru = (old.passthru or { }) // {
      providedSessions = [ name ];
    };
  })
