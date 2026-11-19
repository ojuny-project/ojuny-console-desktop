{ lib }:
{ pkgs, files }:
pkgs.runCommand "check-option-annotation-placement"
  {
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    python3 ${./annotation-gate.py} ${lib.escapeShellArgs (map toString files)}
    touch $out
  ''
