{ pkgs }:
pkgs.runCommand "check-ojuny-console-settings-python"
  {
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    export PYTHONPYCACHEPREFIX=$TMPDIR/pycache
    cp -r ${../packages/console-settings/ojuny_console_settings} .
    python3 -m compileall -q ojuny_console_settings
    python3 -m py_compile ${../packages/steam-shortcut/ojuny-steam-shortcut.py}
    python3 -m py_compile ${../lib/theme-config.py}
    python3 -m py_compile ${../lib/annotation-gate.py}
    touch $out
  ''
