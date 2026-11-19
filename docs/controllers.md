# Controllers

## Frontend key map

| Input | Action |
| --- | --- |
| D-pad or left stick | Move focus |
| A | Activate the focused row or cycle a dropdown |
| B | Move focus to the page buttons, then close the window |
| Start | Open the apply flow |
| LB / RB | Previous or next page |

The movement path uses `Gtk.Window.child_focus`, so it follows the same focus
order as keyboard navigation.

## Where the input comes from

The frontend reads gamepads through libmanette. Manette monitors evdev and raw
HID devices, applies the SDL controller database, and reports standard button
and axis events.

Inside a Steam Big Picture session, Steam Input usually grabs the physical
controller and exposes a virtual controller. Manette sees the virtual device.

## Text fields

Text, path and multiline rows need a keyboard. Steam's on-screen keyboard is
available with Steam+X. The frontend shows a hint when A is pressed on a text
row.

## Numeric rows

Spin and slider rows are rendered with a `Gtk.SpinButton`. A increments the
value. The backend does not expose per-record minimum or maximum values, so the
button uses a wide range. The widget in the desktop settings window remains the
source of truth for bounds.

## Not implemented

- Held-direction repeat for the stick. Movement is rate-limited to 120 ms and
  fires on each axis event.
- Per-controller profiles. Steam Input owns the controller mapping.
- Rumble and LED feedback.
