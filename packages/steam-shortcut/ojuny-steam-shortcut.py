#!/usr/bin/env python3
"""Add or remove the Ojuny settings entry in Steam's shortcuts.vdf.

Steam stores non-Steam shortcuts in a binary VDF file under each numeric
userdata directory. The file is only written while Steam is stopped.
"""

from __future__ import annotations

import argparse
import glob
import os
import struct
import subprocess
import sys
import zlib
from collections import OrderedDict
from dataclasses import dataclass
from typing import Any

TYPE_OBJECT = 0x00
TYPE_STRING = 0x01
TYPE_INT32 = 0x02
TYPE_FLOAT32 = 0x03
TYPE_UINT64 = 0x07
TYPE_END = 0x08

ROOT_KEY = "shortcuts"


class VdfError(Exception):
    pass


def read_cstring(data: bytes, offset: int) -> tuple[str, int]:
    end = data.find(b"\x00", offset)
    if end < 0:
        raise VdfError("unterminated string")
    return data[offset:end].decode("utf-8", "surrogateescape"), end + 1


def read_scalar(data: bytes, offset: int, type_byte: int) -> tuple[Any, int]:
    if type_byte == TYPE_STRING:
        return read_cstring(data, offset)
    if type_byte == TYPE_INT32:
        return struct.unpack_from("<i", data, offset)[0], offset + 4
    if type_byte == TYPE_FLOAT32:
        return struct.unpack_from("<f", data, offset)[0], offset + 4
    if type_byte == TYPE_UINT64:
        return struct.unpack_from("<Q", data, offset)[0], offset + 8
    raise VdfError(f"unsupported VDF type 0x{type_byte:02x}")


def read_entries(data: bytes, offset: int) -> tuple[OrderedDict[str, tuple[int, Any]], int]:
    entries: OrderedDict[str, tuple[int, Any]] = OrderedDict()

    while True:
        if offset >= len(data):
            raise VdfError("unexpected end of VDF data")
        type_byte = data[offset]
        offset += 1

        if type_byte == TYPE_END:
            return entries, offset

        key, offset = read_cstring(data, offset)

        if type_byte == TYPE_OBJECT:
            value, offset = read_entries(data, offset)
        else:
            value, offset = read_scalar(data, offset, type_byte)

        entries[key] = (type_byte, value)


def read_file(data: bytes) -> OrderedDict[str, tuple[int, Any]]:
    if not data:
        return OrderedDict()

    offset = 0
    type_byte = data[offset]
    offset += 1

    if type_byte != TYPE_OBJECT:
        raise VdfError("root entry is not an object")

    key, offset = read_cstring(data, offset)
    if key != ROOT_KEY:
        raise VdfError(f"unexpected root key {key!r}")

    entries, _ = read_entries(data, offset)
    return entries


def write_entries(entries: OrderedDict[str, tuple[int, Any]]) -> bytes:
    output = bytearray()

    for key, (type_byte, value) in entries.items():
        output.append(type_byte)
        output += key.encode("utf-8", "surrogateescape") + b"\x00"

        if type_byte == TYPE_OBJECT:
            output += write_entries(value)
        elif type_byte == TYPE_STRING:
            output += value.encode("utf-8", "surrogateescape") + b"\x00"
        elif type_byte == TYPE_INT32:
            output += struct.pack("<i", value)
        elif type_byte == TYPE_FLOAT32:
            output += struct.pack("<f", value)
        elif type_byte == TYPE_UINT64:
            output += struct.pack("<Q", value)
        else:
            raise VdfError(f"unsupported VDF type 0x{type_byte:02x}")

    output.append(TYPE_END)
    return bytes(output)


def write_file(entries: OrderedDict[str, tuple[int, Any]]) -> bytes:
    return (
        bytes([TYPE_OBJECT])
        + ROOT_KEY.encode("utf-8")
        + b"\x00"
        + write_entries(entries)
        + bytes([TYPE_END])
    )


def app_id(exe: str, name: str) -> tuple[int, int]:
    quoted_exe = f'"{exe}"'
    unsigned = (zlib.crc32((quoted_exe + name).encode("utf-8")) & 0xFFFFFFFF) | 0x80000000
    signed = struct.unpack("<i", struct.pack("<I", unsigned))[0]
    return unsigned, signed


def shortcut_fields(
    exe: str,
    name: str,
    start_dir: str,
    icon: str,
    signed_app_id: int,
    include_last_play_time: bool,
) -> OrderedDict[str, tuple[int, Any]]:
    fields = OrderedDict(
        [
            ("appid", (TYPE_INT32, signed_app_id)),
            ("AppName", (TYPE_STRING, name)),
            ("Exe", (TYPE_STRING, f'"{exe}"')),
            ("StartDir", (TYPE_STRING, f'"{start_dir}"')),
            ("icon", (TYPE_STRING, icon)),
            ("ShortcutPath", (TYPE_STRING, "")),
            ("LaunchOptions", (TYPE_STRING, "")),
            ("IsHidden", (TYPE_INT32, 0)),
            ("AllowDesktopConfig", (TYPE_INT32, 1)),
            ("AllowOverlay", (TYPE_INT32, 1)),
            ("OpenVR", (TYPE_INT32, 0)),
            ("Devkit", (TYPE_INT32, 0)),
            ("DevkitGameID", (TYPE_STRING, "")),
            ("DevkitOverrideAppID", (TYPE_INT32, 0)),
            ("FlatpakAppID", (TYPE_STRING, "")),
        ]
    )

    if include_last_play_time:
        fields["LastPlayTime"] = (TYPE_INT32, 0)

    return fields


def find_entry(entries: OrderedDict[str, tuple[int, Any]], name: str, unsigned_app_id: int) -> str | None:
    for key, (type_byte, value) in entries.items():
        if type_byte != TYPE_OBJECT:
            continue

        found_name = value.get("AppName")
        found_app_id = value.get("appid")

        name_matches = found_name is not None and found_name[1] == name
        id_matches = (
            found_app_id is not None
            and (found_app_id[1] & 0xFFFFFFFF) == unsigned_app_id
        )

        if name_matches or id_matches:
            return key

    return None


def next_index(entries: OrderedDict[str, tuple[int, Any]]) -> str:
    indices = [int(key) for key in entries if key.isdigit()]
    return str(max(indices, default=-1) + 1)


def default_steam_dir() -> str:
    candidates = [
        os.path.expanduser("~/.local/share/Steam"),
        os.path.expanduser("~/.steam/steam"),
    ]
    for candidate in candidates:
        if os.path.isdir(candidate):
            return os.path.realpath(candidate)
    return os.path.realpath(candidates[0])


def steam_is_running() -> bool:
    result = subprocess.run(
        ["pgrep", "-x", "steam"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def update_file(
    path: str,
    name: str,
    exe: str,
    start_dir: str,
    icon: str,
    remove: bool,
) -> bool:
    try:
        with open(path, "rb") as handle:
            entries = read_file(handle.read())
    except FileNotFoundError:
        entries = OrderedDict()
    except (VdfError, OSError) as error:
        print(f"skip {path}: {error}", file=sys.stderr)
        return False

    unsigned_app_id, signed_app_id = app_id(exe, name)
    existing = find_entry(entries, name, unsigned_app_id)

    if remove:
        if existing is None:
            return False
        del entries[existing]
    else:
        fields = shortcut_fields(
            exe,
            name,
            start_dir,
            icon,
            signed_app_id,
            include_last_play_time=existing is None,
        )
        if existing is None:
            entries[next_index(entries)] = (TYPE_OBJECT, fields)
        else:
            entry = entries[existing][1]
            entry.update(fields)

    try:
        mode = os.stat(path).st_mode & 0o777
    except FileNotFoundError:
        mode = 0o644

    temporary = f"{path}.ojuny-tmp"
    with open(temporary, "wb") as handle:
        handle.write(write_file(entries))
    os.chmod(temporary, mode)
    os.replace(temporary, path)
    return True


@dataclass
class Arguments:
    name: str
    exe: str
    start_dir: str
    icon: str
    steam_dir: str
    remove: bool


def parse_arguments() -> Arguments:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", default="Ojuny Settings")
    parser.add_argument("--exe", required=True)
    parser.add_argument("--start-dir", default="~")
    parser.add_argument("--icon", default="")
    parser.add_argument("--steam-dir", default=default_steam_dir())
    parser.add_argument("--remove", action="store_true")

    values = parser.parse_args()
    return Arguments(
        name=values.name,
        exe=os.path.abspath(os.path.expanduser(values.exe)),
        start_dir=os.path.abspath(os.path.expanduser(values.start_dir)),
        icon=values.icon,
        steam_dir=values.steam_dir,
        remove=values.remove,
    )


def main() -> int:
    arguments = parse_arguments()

    if steam_is_running():
        print("Steam is running; shortcuts.vdf was not changed.", file=sys.stderr)
        return 0

    config_dirs = glob.glob(os.path.join(arguments.steam_dir, "userdata", "*", "config"))
    if not config_dirs:
        print("No Steam userdata yet; nothing to update.", file=sys.stderr)
        return 0

    changed = False
    for config_dir in sorted(config_dirs):
        path = os.path.join(config_dir, "shortcuts.vdf")
        if update_file(
            path,
            arguments.name,
            arguments.exe,
            arguments.start_dir,
            arguments.icon,
            arguments.remove,
        ):
            changed = True
            action = "Removed" if arguments.remove else "Wrote"
            print(f"{action} {path}")

    if not changed:
        print("Shortcut already up to date.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
