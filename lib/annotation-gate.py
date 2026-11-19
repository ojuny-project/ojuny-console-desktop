#!/usr/bin/env python3
"""Reject @option annotations that the nix-settings-gui scanner cannot bind.

The documented limitation is that an @option comment binds only to an
assignment in a plain attribute set. It is not supported inside a list,
mkMerge, map, forEach or optionalAttrs. Annotated files therefore keep option
definitions separate from wiring code.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

FORBIDDEN = [
    ("mkMerge", re.compile(r"\bmkMerge\b")),
    ("forEach", re.compile(r"\bforEach\b")),
    ("optionalAttrs", re.compile(r"\boptionalAttrs\b")),
    ("map", re.compile(r"\bmap\s*\(")),
]


def strip_noise(text: str) -> str:
    output: list[str] = []
    index = 0
    length = len(text)

    while index < length:
        character = text[index]

        if character == '"':
            output.append(" ")
            index += 1
            while index < length:
                if text[index] == "\\":
                    output.append(" ")
                    index += 2
                    continue
                if text[index] == '"':
                    output.append(" ")
                    index += 1
                    break
                output.append("\n" if text[index] == "\n" else " ")
                index += 1
            continue

        if character == "'" and index + 1 < length and text[index + 1] == "'":
            output.append("  ")
            index += 2
            while index < length:
                if text.startswith("'''", index):
                    output.append("   ")
                    index += 3
                    continue
                if text.startswith("''${", index):
                    output.append("    ")
                    index += 4
                    continue
                if text.startswith("''", index):
                    output.append("  ")
                    index += 2
                    break
                output.append("\n" if text[index] == "\n" else " ")
                index += 1
            continue

        if character == "#":
            while index < length and text[index] != "\n":
                output.append(" ")
                index += 1
            continue

        if character == "/" and index + 1 < length and text[index + 1] == "*":
            output.append("  ")
            index += 2
            while index + 1 < length and not (text[index] == "*" and text[index + 1] == "/"):
                output.append("\n" if text[index] == "\n" else " ")
                index += 1
            output.append("  ")
            index += 2
            continue

        output.append(character)
        index += 1

    return "".join(output)


def bracket_stack_by_line(text: str) -> list[list[str]]:
    stacks: list[list[str]] = []
    stack: list[str] = []

    for character in text:
        if character == "\n":
            stacks.append(list(stack))
            continue
        if character in "{[(":
            stack.append(character)
        elif character in "}])":
            if stack:
                stack.pop()

    stacks.append(list(stack))
    return stacks


def check_file(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    if not any("@option" in line for line in lines):
        return []

    errors: list[str] = []
    stripped = strip_noise(text)

    for name, pattern in FORBIDDEN:
        match = pattern.search(stripped)
        if match is not None:
            line = stripped.count("\n", 0, match.start()) + 1
            errors.append(
                f"{path}:{line}: @option files must not use {name}; "
                "keep annotated options in a plain attribute set"
            )

    stacks = bracket_stack_by_line(stripped)

    for number, line in enumerate(lines, start=1):
        if "@option" not in line:
            continue

        stack = stacks[number - 1] if number - 1 < len(stacks) else []
        if "[" in stack:
            errors.append(
                f"{path}:{number}: @option is inside a list literal; "
                "an annotation only binds to a plain attribute set"
            )

    return errors


def main() -> int:
    files = [Path(argument) for argument in sys.argv[1:]]
    if not files:
        print("usage: annotation-gate.py FILE...", file=sys.stderr)
        return 2

    errors: list[str] = []
    for path in files:
        errors.extend(check_file(path))

    for error in errors:
        print(error, file=sys.stderr)

    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
