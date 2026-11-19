"""Value helpers mirrored from nix-settings-gui/src/widgets/nix.rs."""

from __future__ import annotations

MODIFIERS = ("lib.mkDefault", "lib.mkForce")


def unwrap_modifiers(text: str) -> str:
    value = text.strip()

    while True:
        rest: str | None = None

        for prefix in MODIFIERS:
            if value.startswith(prefix):
                rest = value[len(prefix):].strip()
                break

        if rest is None and value.startswith("lib.mkOverride"):
            rest = value[len("lib.mkOverride"):].lstrip()
            rest = rest.lstrip("0123456789").strip()

        if not rest:
            return value

        value = rest


def truthy(value: str) -> bool:
    return unwrap_modifiers(value).strip() not in ("false", "null", "0", "0.0")


def quote(text: str) -> str:
    escaped = text.replace("\\", "\\\\").replace('"', '\\"').replace("${", "\\${")
    return f'"{escaped}"'


def unescape(text: str) -> str:
    if len(text) < 2 or not text.startswith('"') or not text.endswith('"'):
        return text
    inner = text[1:-1]
    return inner.replace('\\"', '"').replace("\\${", "${").replace("\\\\", "\\")


def entry_text(value: str) -> str:
    stripped = value.strip()
    if len(stripped) >= 2 and stripped.startswith('"') and stripped.endswith('"'):
        return unescape(stripped)
    return stripped


def parse_string_literal(text: str) -> str:
    stripped = text.strip()
    if len(stripped) >= 4 and stripped.startswith("''") and stripped.endswith("''"):
        return stripped[2:-2].strip("\n")
    return entry_text(stripped)


def string_literal(text: str) -> str:
    if "\n" in text:
        return f"''\n{text}\n''"
    return quote(text)


def path_literal(text: str) -> str:
    stripped = text.strip()
    if stripped.startswith(("./", "../", "/")):
        return stripped
    return quote(stripped)


def choice_literal(raw: str) -> str:
    stripped = raw.strip()
    if stripped in ("true", "false", "null"):
        return stripped
    try:
        float(stripped)
    except ValueError:
        return quote(stripped)
    return stripped
