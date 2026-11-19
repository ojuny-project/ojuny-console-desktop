from __future__ import annotations

import subprocess
import sys
import threading
from dataclasses import dataclass
from typing import Any, Callable

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
gi.require_version("Pango", "1.0")

from gi.repository import Adw, Gdk, GLib, Gtk, Pango  # noqa: E402

from .backend import Backend, BackendError  # noqa: E402
from .gamepad import MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT, MOVE_UP, Gamepad  # noqa: E402
from .nix_values import (  # noqa: E402
    choice_literal,
    entry_text,
    parse_string_literal,
    path_literal,
    string_literal,
    truthy,
    unwrap_modifiers,
)
from .pages import Page, Record, parse_pages  # noqa: E402

STYLE = """
window {
  background: #1a1b26;
  color: #a9b1d6;
}

headerbar {
  background: #16161e;
}

.title {
  font-size: 1.6rem;
  font-weight: 700;
}

.page-button {
  font-size: 1.05rem;
  padding: 0.35rem 1rem;
}

row {
  min-height: 64px;
}
"""


@dataclass
class ConsoleOptions:
    root: str
    apply_command: str | None
    windowed: bool


class ConsoleWindow(Adw.ApplicationWindow):
    def __init__(self, application: Adw.Application, backend: Backend, options: ConsoleOptions) -> None:
        super().__init__(application=application, title="Ojuny Console Settings")

        self._backend = backend
        self._options = options
        self._pages: list[Page] = []
        self._rows_by_page: list[list[Gtk.Widget]] = []
        self._page_buttons: list[Gtk.ToggleButton] = []
        self._current = 0
        self._dirty: set[str] = set()
        self._switching = False

        self.set_default_size(1280, 720)

        self._toolbar = Adw.ToolbarView()
        self._header = Adw.HeaderBar()
        self._title = Gtk.Label(label="Ojuny Console", xalign=0)
        self._title.add_css_class("title")
        self._header.set_title_widget(self._title)

        self._page_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self._page_box.add_css_class("linked")
        self._header.pack_start(self._page_box)

        self._status = Gtk.Label(label="Loading settings...", xalign=0)
        self._status.set_hexpand(True)
        self._status.set_ellipsize(Pango.EllipsizeMode.END)

        self._apply_button = Gtk.Button(label="Apply")
        self._apply_button.add_css_class("suggested-action")
        self._apply_button.set_sensitive(False)
        self._apply_button.connect("clicked", lambda _button: self._apply())

        footer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        footer.set_margin_top(12)
        footer.set_margin_bottom(12)
        footer.set_margin_start(24)
        footer.set_margin_end(24)
        footer.append(self._status)
        footer.append(self._apply_button)

        self._stack = Gtk.Stack()
        self._stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)

        self._toolbar.add_top_bar(self._header)
        self._toolbar.add_bottom_bar(footer)
        self._toolbar.set_content(self._stack)
        self.set_content(self._toolbar)

        self._gamepad = Gamepad(
            on_move=self._move,
            on_activate=self._activate_focused,
            on_back=self._back,
            on_page=self._page,
            on_apply=self._apply,
        )

        self._install_style()

    def load(self) -> None:
        try:
            self._gamepad.start()
        except Exception as error:
            print(f"controller input unavailable: {error}", file=sys.stderr)

        try:
            self._backend.start()
        except OSError as error:
            self._show_error(f"Cannot start the settings backend: {error}")
            return

        self._call("session.open", {"root": self._options.root}, self._after_open, self._fail)

    def _call(
        self,
        method: str,
        params: dict[str, Any] | None,
        on_success: Callable[[Any], None],
        on_error: Callable[[Exception], None] | None = None,
    ) -> None:
        def worker() -> None:
            try:
                result = self._backend.call(method, params)
            except BackendError as error:
                GLib.idle_add(on_error or self._fail, error)
            else:
                GLib.idle_add(on_success, result)

        threading.Thread(target=worker, daemon=True).start()

    def _after_open(self, _result: Any) -> None:
        self._call("scan", None, self._after_scan, self._fail)

    def _after_scan(self, result: Any) -> None:
        self._pages = parse_pages(result)

        if not self._pages:
            self._show_error("No annotated settings pages were found in the selected configuration.")
            return

        self._build_pages()
        self._status.set_text(f"{len(self._pages)} pages")
        self._show_page(0)

    def _build_pages(self) -> None:
        for index, page in enumerate(self._pages):
            button = Gtk.ToggleButton(label=page.title)
            button.add_css_class("page-button")
            button.connect("toggled", self._page_toggled, index)
            self._page_box.append(button)
            self._page_buttons.append(button)

            widget = Adw.PreferencesPage()
            group = Adw.PreferencesGroup()
            rows: list[Gtk.Widget] = []

            for record in page.records:
                row = self._make_row(record)
                group.add(row)
                rows.append(row)

            widget.add(group)

            if page.advanced:
                advanced_group = Adw.PreferencesGroup(title="Advanced")
                for record in page.advanced:
                    row = self._make_row(record)
                    advanced_group.add(row)
                    rows.append(row)
                widget.add(advanced_group)

            self._stack.add_named(widget, page.id)
            self._rows_by_page.append(rows)

    def _make_row(self, record: Record) -> Adw.PreferencesRow:
        row: Adw.PreferencesRow

        if record.widget == "switch":
            switch_row = Adw.SwitchRow(title=record.label, subtitle=record.description)
            switch_row.set_active(truthy(record.value))
            switch_row.connect(
                "notify::active",
                lambda widget, _property: self._stage(
                    record, "true" if widget.get_active() else "false"
                ),
            )
            row = switch_row
        elif record.widget in ("dropdown", "radio") and record.choices:
            combo_row = Adw.ComboRow(
                title=record.label,
                subtitle=record.description,
                model=Gtk.StringList.new(record.choices),
            )
            current = entry_text(unwrap_modifiers(record.value))
            if current in record.choices:
                combo_row.set_selected(record.choices.index(current))
            combo_row.connect(
                "notify::selected",
                lambda widget, _property: self._stage(
                    record, choice_literal(record.choices[widget.get_selected()])
                ),
            )
            row = combo_row
        elif record.widget in ("spin", "slider"):
            try:
                value = float(unwrap_modifiers(record.value))
            except ValueError:
                value = 0.0

            spin = Gtk.SpinButton(
                adjustment=Gtk.Adjustment(
                    value=value,
                    lower=-1_000_000,
                    upper=1_000_000,
                    step_increment=1,
                ),
                climb_rate=1,
                digits=0,
            )
            spin.connect(
                "value-changed",
                lambda widget: self._stage(record, str(int(widget.get_value()))),
            )
            action_row = Adw.ActionRow(title=record.label, subtitle=record.description)
            action_row.add_suffix(spin)
            row = action_row
        elif record.widget in ("text", "path", "multiline", "color"):
            entry_row = Adw.EntryRow(title=record.label)
            current = unwrap_modifiers(record.value)
            if record.widget == "path":
                entry_row.set_text(entry_text(current))
            else:
                entry_row.set_text(parse_string_literal(current))
            entry_row.connect(
                "apply",
                lambda widget: self._stage(record, self._entry_literal(record, widget.get_text())),
            )
            row = entry_row
        else:
            action_row = Adw.ActionRow(title=record.label)
            detail = record.description or entry_text(unwrap_modifiers(record.value))
            action_row.set_subtitle(detail)
            action_row.set_activatable(False)
            row = action_row

        if record.readonly:
            row.set_sensitive(False)

        row.set_tooltip_text(record.path)
        return row

    def _entry_literal(self, record: Record, text: str) -> str:
        if record.widget == "path":
            return path_literal(text)
        return string_literal(text)

    def _stage(self, record: Record, value: str) -> None:
        self._dirty.add(record.path)
        self._status.set_text(f"{len(self._dirty)} unsaved change(s)")
        self._apply_button.set_sensitive(True)
        self._call("control.set", {"path": record.path, "value": value}, lambda _result: None, self._fail)

    def _apply(self) -> None:
        if not self._dirty:
            self._status.set_text("No unsaved changes.")
            return

        self._call("edits.preview", None, self._confirm_apply, self._fail)

    def _confirm_apply(self, preview: Any) -> None:
        edits = preview.get("edits", [])
        dialog = Adw.AlertDialog(
            heading="Apply changes?",
            body=f"{len(edits)} value(s) will be written to the configuration.",
        )
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("apply", "Apply")
        dialog.set_response_appearance("apply", Adw.ResponseAppearance.SUGGESTED)
        dialog.connect("response", self._on_apply_response)
        dialog.present(self)

    def _on_apply_response(self, _dialog: Adw.AlertDialog, response: str) -> None:
        if response != "apply":
            return

        self._status.set_text("Saving...")
        self._call("edits.apply", None, self._after_apply, self._fail)

    def _after_apply(self, result: Any) -> None:
        files = result.get("files", 0)
        self._dirty.clear()
        self._apply_button.set_sensitive(False)
        self._status.set_text(f"Saved {files} file(s).")

        if self._options.apply_command is None:
            return

        dialog = Adw.AlertDialog(
            heading="Rebuild now?",
            body="The saved values take effect after the configuration is rebuilt.",
        )
        dialog.add_response("later", "Later")
        dialog.add_response("rebuild", "Rebuild")
        dialog.set_response_appearance("rebuild", Adw.ResponseAppearance.SUGGESTED)
        dialog.connect("response", self._on_rebuild_response)
        dialog.present(self)

    def _on_rebuild_response(self, _dialog: Adw.AlertDialog, response: str) -> None:
        if response != "rebuild" or self._options.apply_command is None:
            return

        subprocess.Popen(
            ["/bin/sh", "-lc", self._options.apply_command],
            start_new_session=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        self._status.set_text("Rebuild started.")

    def _page_toggled(self, button: Gtk.ToggleButton, index: int) -> None:
        if self._switching or not button.get_active():
            return
        self._show_page(index)

    def _show_page(self, index: int) -> None:
        if not self._pages:
            return

        self._current = index % len(self._pages)
        page = self._pages[self._current]
        self._stack.set_visible_child_name(page.id)

        self._switching = True
        for button_index, button in enumerate(self._page_buttons):
            button.set_active(button_index == self._current)
        self._switching = False

        self._focus_first_row()

    def _focus_first_row(self) -> None:
        rows = self._rows_by_page[self._current]
        if rows:
            rows[0].grab_focus()

    def _move(self, direction: str) -> None:
        directions = {
            MOVE_UP: Gtk.DirectionType.UP,
            MOVE_DOWN: Gtk.DirectionType.DOWN,
            MOVE_LEFT: Gtk.DirectionType.LEFT,
            MOVE_RIGHT: Gtk.DirectionType.RIGHT,
        }

        if self.get_focus() is None:
            self._focus_first_row()
            return

        self.child_focus(directions[direction])

    def _activate_focused(self) -> None:
        focused = self.get_focus()

        if isinstance(focused, Adw.SwitchRow):
            focused.set_active(not focused.get_active())
        elif isinstance(focused, Adw.ComboRow):
            model = focused.get_model()
            count = model.get_n_items() if model is not None else 0
            if count:
                focused.set_selected((focused.get_selected() + 1) % count)
        elif isinstance(focused, Gtk.SpinButton):
            focused.spin(Gtk.SpinType.STEP_FORWARD, 1)
        elif isinstance(focused, Adw.EntryRow):
            self._status.set_text("Text fields need a keyboard. Use Steam+X for the on-screen keyboard.")
        elif focused is not None:
            focused.activate()

    def _back(self) -> None:
        if not self._pages:
            self.close()
            return

        focused = self.get_focus()
        on_page_buttons = any(focused is button for button in self._page_buttons)

        if on_page_buttons:
            if self._dirty:
                self._status.set_text("Apply or discard changes before leaving.")
            else:
                self.close()
            return

        self._page_buttons[self._current].grab_focus()

    def _page(self, delta: int) -> None:
        if self._pages:
            self._show_page(self._current + delta)

    def _fail(self, error: Exception) -> None:
        self._status.set_text(str(error))
        if not self._pages:
            self._show_error(str(error))

    def _show_error(self, message: str) -> None:
        if self._stack.get_child_by_name("error") is None:
            status = Adw.StatusPage(
                title="Settings unavailable",
                description=message,
                icon_name="dialog-error-symbolic",
            )
            self._stack.add_named(status, "error")

        self._stack.set_visible_child_name("error")
        self._status.set_text(message)

    def _install_style(self) -> None:
        display = Gdk.Display.get_default()
        if display is None:
            return

        provider = Gtk.CssProvider()
        provider.load_from_data(STYLE.encode())
        Gtk.StyleContext.add_provider_for_display(
            display,
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )
