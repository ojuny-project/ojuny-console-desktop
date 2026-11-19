{ pkgs, lib }:
let
  session = (import ../lib/mk-session.nix { inherit lib pkgs; }) {
    name = "ojuny-console";
    comment = "session fixture";
    exec = "/bin/true";
  };
in
assert lib.assertMsg (
  session.providedSessions == [ "ojuny-console" ]
) "session package must provide only the ojuny-console session";
pkgs.runCommand "check-ojuny-console-session" { } ''
  test -f ${session}/share/wayland-sessions/ojuny-console.desktop
  test ! -e ${session}/share/wayland-sessions/steam.desktop
  grep -q 'Exec=/bin/true' ${session}/share/wayland-sessions/ojuny-console.desktop
  touch $out
''
