# DRAFT - ojuny-console-desktop

Status: draft scope. Nothing is built. This file describes what the repository
is supposed to contain, not what it contains today.

## Purpose

The session layer for Ojuny Console. It provides the gaming session, the
controller-first behavior and the switch between Steam Big Picture Mode and the
desktop target. It exports a NixOS module and a Home Manager module, like
`ojuny-desktop` does for the core desktop.

It does not contain a host, a user, an installer or the application catalog.
The Console template consumes this flake.

## What the repository will contain

```text
ojuny-console-desktop/
  flake.nix                  session package and modules
  modules/
    session.nix              gaming and desktop session definitions
    steam.nix                Steam and Proton defaults
    display.nix              TV display, HDR and VRR
    audio.nix                HDMI and controller audio defaults
    input.nix                controller and remote input handling
    power.nix                console power and idle behavior
    autologin.nix            account and session selection
  packages/                  wrappers and session helpers
  docs/                      options, session design, hardware notes
  tests/                     evaluation and session checks
```

### Flake outputs

- `packages.ojuny-console-session`: the gaming session package.
- `nixosModules.default`: installs the sessions, auto-login and services.
- `homeManagerModules.default`: installs the user-level session pieces.
- `apps.run`: a nested console session for evaluation.
- Checks that evaluate the modules and the session definitions.

### Option surface

A single shared surface for NixOS and Home Manager. The namespace is to be
decided, with `desktop.ojuny.console.*` as the current candidate.

The surface covers:

- Default session: gaming or desktop.
- Auto-login account and whether auto-login is enabled.
- Session command and compositor settings.
- Steam launch arguments and Big Picture behavior.
- Display mode, resolution, refresh rate, HDR and VRR.
- Audio output and channel configuration.
- Controller profiles, dead zones and button mapping.
- Idle, suspend and shutdown behavior on a TV.
- Desktop target selection when a desktop layer is installed.
- On-screen performance overlay and frame limiting.

### Session behavior

- The gaming session starts Steam Big Picture directly, without a desktop
  shell in front of it.
- The session is controller-navigable from the first screen.
- Exiting Steam offers the desktop target instead of dropping to a black
  screen or a bare TTY.
- If the gaming session fails, a recovery path starts the desktop or a login
  prompt.
- The desktop target is a separate session entry so a display manager can
  launch either one.
- Auto-login selects the gaming session; disabling it restores the greeter.

### Documentation

- Every option and its default.
- The launch path for the gaming session and the desktop target.
- Controller pairing and mapping.
- HDR, VRR and audio caveats per GPU vendor.
- Recovery when Steam or the compositor fails to start.

### Tests

- The flake evaluates and the session package builds.
- A VM starts the gaming session and reaches Steam.
- A VM starts the desktop target.
- Auto-login can be enabled and disabled.
- A failed gaming session falls back to the recovery path.
- Controller input reaches the session in a headless test where possible.

## Limits and non-goals

- The gaming session depends on Steam and a working GPU driver.
- HDR and VRR support depends on the kernel, Mesa and the display.
- No game compatibility guarantee.
- No Steam account handling in Nix.
- No desktop environment of its own. It consumes another desktop module.
- No remote management service. `nix-web-gui` belongs to the template.
- No handheld or console hardware certification.

## Open questions

- Is the desktop target a required input, an optional input, or a separate
  module the template selects?
- Does the gaming session use gamescope directly, a Steam session manager, or a
  custom wrapper?
- Are controller profiles stored as Nix options, data files, or both?
- Does the flake ship a nested runner, or is a VM the only honest test?
- How are per-game Proton overrides handled without mutable Steam state?

## Sources

- `ojuny-desktop/README.md` and `DESIGN.md` for the module and session shape.
- `nixos-configs/notes/Ojuny Deployment Methods.md`.
- `ojuny-docs/02-project-architecture.md`.
