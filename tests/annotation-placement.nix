{ pkgs, lib }:
pkgs.runCommand "check-option-annotation-placement"
  {
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    set +e
    python3 ${../lib/annotation-gate.py} ${./fixtures/annotations-good.nix}
    good=$?
    python3 ${../lib/annotation-gate.py} ${./fixtures/annotations-good-string.nix}
    good_string=$?
    python3 ${../lib/annotation-gate.py} ${./fixtures/annotations-bad-list.nix}
    bad_list=$?
    python3 ${../lib/annotation-gate.py} ${./fixtures/annotations-bad-mkmerge.nix}
    bad_mkmerge=$?
    set -e

    test "$good" -eq 0
    test "$good_string" -eq 0
    test "$bad_list" -ne 0
    test "$bad_mkmerge" -ne 0

    touch $out
  ''
