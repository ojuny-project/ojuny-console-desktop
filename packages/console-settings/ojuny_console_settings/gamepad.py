from __future__ import annotations

from collections.abc import Callable, Iterator
from typing import Any

import gi

gi.require_version("Manette", "0.2")

from gi.repository import GLib, Manette  # noqa: E402

BTN_SOUTH = 0x130
BTN_EAST = 0x131
BTN_SELECT = 0x13A
BTN_START = 0x13B
BTN_LEFT_SHOULDER = 0x136
BTN_RIGHT_SHOULDER = 0x137

BTN_DPAD_UP = 0x220
BTN_DPAD_DOWN = 0x221
BTN_DPAD_LEFT = 0x222
BTN_DPAD_RIGHT = 0x223

ABS_X = 0x00
ABS_Y = 0x01
ABS_HAT0X = 0x10
ABS_HAT0Y = 0x11

EVENT_BUTTON_PRESS = 0
EVENT_BUTTON_RELEASE = 1
EVENT_ABSOLUTE = 2
EVENT_HAT = 3

MOVE_UP = "up"
MOVE_DOWN = "down"
MOVE_LEFT = "left"
MOVE_RIGHT = "right"


class Gamepad:
    """Map a controller to the window's focus and page actions."""

    def __init__(
        self,
        on_move: Callable[[str], None],
        on_activate: Callable[[], None],
        on_back: Callable[[], None],
        on_page: Callable[[int], None],
        on_apply: Callable[[], None],
    ) -> None:
        self._on_move = on_move
        self._on_activate = on_activate
        self._on_back = on_back
        self._on_page = on_page
        self._on_apply = on_apply

        self._monitor = Manette.Monitor()
        self._monitor.connect("device-connected", self._device_connected)
        self._devices: set[Any] = set()
        self._last_move = 0

    def start(self) -> None:
        for device in self._iter_devices():
            self._device_connected(self._monitor, device)

    def _iter_devices(self) -> Iterator[Any]:
        iterator = self._monitor.iterate()

        while True:
            result = iterator.next()
            if isinstance(result, tuple):
                more, device = result
            else:
                more, device = bool(result), result

            if not more:
                return

            yield device

    def _device_connected(self, _monitor: Any, device: Any) -> None:
        if device in self._devices:
            return
        self._devices.add(device)
        device.connect("event", self._event)

    def _event(self, _device: Any, event: Any) -> None:
        event_type = event.get_event_type()

        if event_type == EVENT_BUTTON_PRESS:
            pressed, button = event.get_button()
            if pressed:
                self._button(button)
        elif event_type == EVENT_HAT:
            pressed, axis, value = event.get_hat()
            if pressed:
                self._hat(axis, value)
        elif event_type == EVENT_ABSOLUTE:
            pressed, axis, value = event.get_absolute()
            if pressed:
                self._axis(axis, value)

    def _button(self, button: int) -> None:
        if button == BTN_SOUTH:
            self._on_activate()
        elif button in (BTN_EAST, BTN_SELECT):
            self._on_back()
        elif button == BTN_START:
            self._on_apply()
        elif button == BTN_LEFT_SHOULDER:
            self._on_page(-1)
        elif button == BTN_RIGHT_SHOULDER:
            self._on_page(1)
        elif button == BTN_DPAD_UP:
            self._move(MOVE_UP)
        elif button == BTN_DPAD_DOWN:
            self._move(MOVE_DOWN)
        elif button == BTN_DPAD_LEFT:
            self._move(MOVE_LEFT)
        elif button == BTN_DPAD_RIGHT:
            self._move(MOVE_RIGHT)

    def _hat(self, axis: int, value: int) -> None:
        if axis == ABS_HAT0X and value != 0:
            self._move(MOVE_RIGHT if value > 0 else MOVE_LEFT)
        elif axis == ABS_HAT0Y and value != 0:
            self._move(MOVE_DOWN if value > 0 else MOVE_UP)

    def _axis(self, axis: int, value: float) -> None:
        if abs(value) < 0.6:
            return

        if axis == ABS_X:
            self._move(MOVE_RIGHT if value > 0 else MOVE_LEFT)
        elif axis == ABS_Y:
            self._move(MOVE_DOWN if value > 0 else MOVE_UP)

    def _move(self, direction: str) -> None:
        now = GLib.get_monotonic_time()
        if now - self._last_move < 120_000:
            return

        self._last_move = now
        self._on_move(direction)
