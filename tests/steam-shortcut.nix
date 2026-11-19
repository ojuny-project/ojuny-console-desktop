{ pkgs }:
pkgs.runCommand "check-ojuny-console-shortcut"
  {
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    export HOME=$TMPDIR/home
    mkdir -p "$HOME/.local/share/Steam/userdata/123/config"

    mkdir -p "$TMPDIR/bin"
    cat > "$TMPDIR/bin/pgrep" <<'EOF'
    #!/bin/sh
    exit 1
    EOF
    chmod +x "$TMPDIR/bin/pgrep"
    export PATH="$TMPDIR/bin:$PATH"

    touch "$TMPDIR/settings"

    python3 ${../packages/steam-shortcut/ojuny-steam-shortcut.py} \
      --name "Ojuny Settings" \
      --exe "$TMPDIR/settings" \
      --start-dir "$TMPDIR"

    python3 - \
      "$HOME/.local/share/Steam/userdata/123/config/shortcuts.vdf" \
      ${../packages/steam-shortcut/ojuny-steam-shortcut.py} <<'EOF'
    import importlib.util
    import sys

    path, source = sys.argv[1], sys.argv[2]
    spec = importlib.util.spec_from_file_location("shortcut", source)
    module = importlib.util.module_from_spec(spec)
    sys.modules["shortcut"] = module
    spec.loader.exec_module(module)

    entries = module.read_file(open(path, "rb").read())
    entry = next(iter(entries.values()))[1]
    entry["LastPlayTime"] = (module.TYPE_INT32, 1234)
    open(path, "wb").write(module.write_file(entries))
    EOF

    python3 ${../packages/steam-shortcut/ojuny-steam-shortcut.py} \
      --name "Ojuny Settings" \
      --exe "$TMPDIR/settings" \
      --start-dir "$TMPDIR"

    python3 - \
      "$HOME/.local/share/Steam/userdata/123/config/shortcuts.vdf" \
      ${../packages/steam-shortcut/ojuny-steam-shortcut.py} \
      "$TMPDIR/settings" <<'EOF'
    import importlib.util
    import sys
    import zlib

    path, source, exe = sys.argv[1], sys.argv[2], sys.argv[3]
    spec = importlib.util.spec_from_file_location("shortcut", source)
    module = importlib.util.module_from_spec(spec)
    sys.modules["shortcut"] = module
    spec.loader.exec_module(module)

    entries = module.read_file(open(path, "rb").read())
    assert len(entries) == 1, entries
    entry = next(iter(entries.values()))[1]
    assert entry["AppName"][1] == "Ojuny Settings"
    assert entry["Exe"][1].strip('"') == exe
    assert entry["LastPlayTime"][1] == 1234

    expected = (zlib.crc32(f'"{exe}"Ojuny Settings'.encode()) & 0xFFFFFFFF) | 0x80000000
    assert entry["appid"][1] & 0xFFFFFFFF == expected

    assert module.write_file(entries) == open(path, "rb").read()
    EOF

    touch $out
  ''
