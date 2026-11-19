from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class Record:
    path: str
    label: str
    value: str
    widget: str
    file: str
    choices: list[str] = field(default_factory=list)
    description: str = ""
    advanced: bool = False
    hidden: bool = False
    readonly: bool = False

    @classmethod
    def from_json(cls, data: dict[str, Any]) -> "Record":
        choices = data.get("choices") or []
        if isinstance(choices, dict):
            choices = [str(key) for key in choices]

        return cls(
            path=data.get("path", ""),
            label=data.get("label", data.get("path", "")),
            value="" if data.get("value") is None else str(data.get("value")),
            widget=data.get("widget", ""),
            file=data.get("file", ""),
            choices=[str(choice) for choice in choices],
            description=data.get("description") or "",
            advanced=bool(data.get("advanced")),
            hidden=bool(data.get("hidden")),
            readonly=bool(data.get("readonly")),
        )


@dataclass
class Page:
    id: str
    title: str
    records: list[Record]
    advanced: list[Record] = field(default_factory=list)


def parse_pages(scan_result: dict[str, Any]) -> list[Page]:
    pages: list[Page] = []

    for menu in scan_result.get("menus", []):
        records = [Record.from_json(entry) for entry in menu.get("records", [])]
        visible = [record for record in records if not record.hidden]
        normal = [record for record in visible if not record.advanced]
        advanced = [record for record in visible if record.advanced]

        if not visible:
            continue

        pages.append(
            Page(
                id=str(len(pages)),
                title=menu.get("displayname", "Settings"),
                records=normal,
                advanced=advanced,
            )
        )

    return pages
