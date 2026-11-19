#!/usr/bin/env python3
"""Enroll the Ojuny theme without overriding a later user choice."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: theme-config.py CONFIG_PATH THEME_NAME MARKER_PATH", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    theme_name = sys.argv[2]
    marker = Path(sys.argv[3])

    marker_value = marker.read_text(encoding="utf-8").strip() if marker.exists() else None

    if marker_value == theme_name and path.exists():
        return 0

    data: dict = {}
    if path.exists():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            print(f"{path}: {error}; leaving Millennium config unchanged", file=sys.stderr)
            return 0

    if not isinstance(data, dict):
        print(f"{path}: root is not an object; leaving it unchanged", file=sys.stderr)
        return 0

    themes = data.setdefault("themes", {})
    if not isinstance(themes, dict):
        print(f"{path}: themes is not an object; leaving it unchanged", file=sys.stderr)
        return 0

    changed = False
    active = themes.get("activeTheme")

    if marker_value is None:
        if active in (None, "", "default"):
            themes["activeTheme"] = theme_name
            changed = True
    elif marker_value != theme_name:
        themes["activeTheme"] = theme_name
        changed = True
    elif active is None:
        themes["activeTheme"] = theme_name
        changed = True

    if changed:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_name(path.name + ".ojuny-tmp")
        temporary.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        os.replace(temporary, path)

    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.write_text(theme_name + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
