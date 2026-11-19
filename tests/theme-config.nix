{ pkgs }:
pkgs.runCommand "check-ojuny-console-theme-config"
  {
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    export HOME=$TMPDIR/home
    mkdir -p "$HOME"

    config="$HOME/config.json"
    marker="$HOME/state/theme-enrolled"

    printf '{"themes": {"activeTheme": "default"}}\n' > "$config"

    python3 ${../lib/theme-config.py} "$config" ojuny-console "$marker"
    python3 - "$config" <<'EOF'
    import json
    import sys

    data = json.load(open(sys.argv[1]))
    assert data["themes"]["activeTheme"] == "ojuny-console", data
    EOF

    printf '{"themes": {"activeTheme": "custom"}}\n' > "$config"
    python3 ${../lib/theme-config.py} "$config" ojuny-console "$marker"
    python3 - "$config" <<'EOF'
    import json
    import sys

    data = json.load(open(sys.argv[1]))
    assert data["themes"]["activeTheme"] == "custom", data
    EOF

    printf '{"themes": {"activeTheme": "custom"}}\n' > "$config"
    marker="$HOME/state/theme-enrolled-2"
    python3 ${../lib/theme-config.py} "$config" ojuny-console "$marker"
    python3 - "$config" <<'EOF'
    import json
    import sys

    data = json.load(open(sys.argv[1]))
    assert data["themes"]["activeTheme"] == "custom", data
    EOF

    printf '{"themes": {"activeTheme": "ojuny-console"}}\n' > "$config"
    python3 ${../lib/theme-config.py} "$config" other-theme "$HOME/state/theme-enrolled"
    python3 - "$config" <<'EOF'
    import json
    import sys

    data = json.load(open(sys.argv[1]))
    assert data["themes"]["activeTheme"] == "other-theme", data
    EOF

    touch $out
  ''
