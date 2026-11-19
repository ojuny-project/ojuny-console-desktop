from __future__ import annotations

import argparse
import os
import sys

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, Gio  # noqa: E402

from .backend import Backend  # noqa: E402
from .ui import ConsoleOptions, ConsoleWindow  # noqa: E402

APPLICATION_ID = "org.ojuny.ConsoleSettings"


class ConsoleApplication(Adw.Application):
    def __init__(self, backend_path: str, options: ConsoleOptions) -> None:
        super().__init__(
            application_id=APPLICATION_ID,
            flags=Gio.ApplicationFlags.FLAGS_NONE,
        )
        self._options = options
        self._backend = Backend(backend_path)
        self._window: ConsoleWindow | None = None

    def do_startup(self) -> None:
        Adw.Application.do_startup(self)
        Adw.StyleManager.get_default().set_color_scheme(Adw.ColorScheme.FORCE_DARK)

    def do_activate(self) -> None:
        if self._window is None:
            self._window = ConsoleWindow(self, self._backend, self._options)
            self._window.load()

        self._window.present()

        if not self._options.windowed:
            self._window.fullscreen()

    def do_shutdown(self) -> None:
        self._backend.close()
        Adw.Application.do_shutdown(self)


def parse_arguments() -> ConsoleOptions:
    parser = argparse.ArgumentParser(
        prog="ojuny-console-settings",
        description="Ojuny Console settings frontend",
    )
    parser.add_argument(
        "--root",
        default=os.environ.get("OJUNY_CONSOLE_SETTINGS_ROOT"),
        help="flake or configuration directory to edit",
    )
    parser.add_argument(
        "--apply-command",
        default=os.environ.get("OJUNY_CONSOLE_SETTINGS_APPLY_COMMAND"),
        help="command run after saving",
    )
    parser.add_argument(
        "--windowed",
        action="store_true",
        help="do not enter fullscreen",
    )

    values = parser.parse_args()

    if not values.root:
        parser.error("--root is required (or set OJUNY_CONSOLE_SETTINGS_ROOT)")

    return ConsoleOptions(
        root=os.path.abspath(os.path.expanduser(values.root)),
        apply_command=values.apply_command,
        windowed=values.windowed,
    )


def main() -> int:
    backend_path = os.environ.get("OJUNY_CONSOLE_SETTINGS_BACKEND")
    if not backend_path:
        print("OJUNY_CONSOLE_SETTINGS_BACKEND is not set", file=sys.stderr)
        return 1

    options = parse_arguments()
    application = ConsoleApplication(backend_path, options)
    return application.run([sys.argv[0]])
