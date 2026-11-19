# Steam state

Nix owns the session, the theme files and the shortcut definition. Steam owns
the account, the library and the userdata directory. The boundary is explicit.

## What this repository writes

| Path | Owner | Reconcile policy |
| --- | --- | --- |
| `~/.steam/steam/millennium/themes/<name>` | Nix | Symlink, replaced on rebuild |
| `~/.config/millennium/config.json` | Steam and Nix | `themes.activeTheme` is set only when absent |
| `~/.local/share/Steam/userdata/<id>/config/shortcuts.vdf` | Steam and Nix | One entry is added or updated while Steam is stopped |
| `~/.local/state` and Steam logs | Steam | Not managed |

## Non-Steam shortcut

The shortcut entry is stored as binary VDF. The app id is the CRC32 of the
executable and name with the high bit set. The reconciler:

1. Finds numeric userdata directories.
2. Parses each `shortcuts.vdf`.
3. Matches an entry by app name or app id.
4. Updates or appends one entry.
5. Writes a temporary file and replaces the original atomically.

It refuses to write while `steam` is running. The user service runs before the
graphical session, so the normal path is safe.

Removal uses the same matcher and deletes only the entry this repository owns.
`--remove` is available on `ojuny-console-shortcut`.

## Millennium configuration

The theme is active when `themes.activeTheme` equals the theme directory name.
The enrollment service never overwrites an existing value, so a theme selected
in Millennium survives a rebuild.

If Millennium has never run, the service creates a minimal `config.json`. If the
file is invalid JSON, the service leaves it alone and prints the parse error.

Enrollment runs at login. After the first enrollment, restart Steam once so
Millennium picks up the theme.

## Steam login

The repository never stores a Steam account. The first launch asks for a login.
The shortcut reconciler skips systems with no userdata directory and runs again
on the next login.

## Controller state

Steam Input stores controller layouts under the Steam userdata directory. This
repository does not manage them. The frontend reads the virtual controller that
Steam exposes to a launched non-Steam application.
