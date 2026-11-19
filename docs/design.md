# Design

## Repository shape

The flake mirrors `ojuny-desktop`:

```text
flake.nix
modules/
  flake/        package and check wiring
  nixos/        NixOS module pieces
  home-manager/ Home Manager module pieces
lib/            option definitions, generation helpers, scripts
packages/       session, theme, shortcut, settings frontend
docs/
tests/
```

Options are defined once in `lib/ojuny-options.nix` and imported by both module
entrypoints.

## Session

`packages/console-session` builds the wrapper. `lib/mk-session.nix` writes the
desktop file and its `passthru.providedSessions`. The module builds its own
session package with the actual Steam package, so the session uses the
Millennium-wrapped Steam when Millennium is enabled.

The flake package uses `steam` from `PATH` because Steam is unfree. The module
passes an absolute package path.

## Millennium theme

`lib/mk-millennium-theme.nix` writes a theme directory with:

- `skin.json`, including `UseDefaultPatches` and `Steam-WebKit`.
- `bigpicture.custom.css`, generated from base16 colors.
- `webkit.css`, generated from the same palette for store and community pages.
- `header.svg`, a local placeholder image.

Millennium's default patches target `^Steam Big Picture Mode$`,
`^QuickAccess_` and `^MainMenu_`, so the theme applies to Big Picture and the
Quick Access Menu without per-target configuration.

A user service links the theme into
`~/.steam/steam/millennium/themes/<name>` and sets `themes.activeTheme` in
`~/.config/millennium/config.json` only when the key is absent. A theme chosen
later in Millennium is preserved.

The service skips the first login when Steam has not created `~/.steam/steam`
yet. It enrolls on the next login.

## Settings boundary

The frontend talks to `nix-settings-backend --stdio`, the JSON-RPC endpoint from
the `nix-settings-gui` flake. It uses these methods:

- `session.open`
- `scan`
- `control.get`
- `control.set`
- `edits.preview`
- `edits.apply`

The backend writes files with the same parse check and formatting as the
desktop settings window. It does not rebuild. The frontend runs
`settings.applyCommand` after a confirmation when the option is set.

## Console frontend

The frontend is a GTK4 and libadwaita application. It is not the desktop
settings window with a different stylesheet.

- Pages come from the template's `@menu` annotations.
- Normal controls and an Advanced group are rendered separately.
- The controller is read through libmanette.
- The window is fullscreen by default and uses TV-scale spacing and type.
- The footer shows staged change count, Apply, and the apply state.

## Shortcut reconciler

`packages/steam-shortcut` parses and rewrites `shortcuts.vdf` in every numeric
Steam userdata directory. It matches an existing entry by app name or app id,
updates it, or appends a new one. It skips the write when Steam is running.

The service runs at `default.target` before `graphical-session.target`, which is
also before Steam starts.

## Tests

Cheap checks cover the session desktop file, the theme files, Python syntax and
the annotation gate. The NixOS VM test is exposed as a package, not as a
`nix flake check` check, because it builds a full system with Steam.

## Annotation gate

`lib/annotation-gate.py` rejects `@option` annotations in files that use
`mkMerge`, `map (`, `forEach` or `optionalAttrs`, and rejects annotations inside
list literals. Annotated options belong in a plain attribute set. `lib.mkIf`
attribute sets are allowed.

The gate is exported as `lib.annotationCheck` so the template can run it on its
own settings pages. It covers the documented constructs: lists, `mkMerge`,
`map`, `forEach` and `optionalAttrs`. An annotation inside an arbitrary function
application is outside the supported shape and is not detected.
