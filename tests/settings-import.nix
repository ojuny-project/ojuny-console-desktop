{ pkgs, settings }:
pkgs.runCommand "check-ojuny-console-settings-import" { } ''
  ${settings}/bin/ojuny-console-settings --help > /dev/null
  touch $out
''
