# ojuny-console-desktop

The session layer for Ojuny Console. It provides a gamescope Steam Big Picture
session, a Millennium theme for Big Picture, a controller-first settings
frontend and a non-Steam shortcut that opens it from inside Steam. It exports a
NixOS module, a Home Manager module and standalone packages.

Status: implemented, not hardware-tested. Flake evaluation and the cheap checks
pass. The VM test is available as a package and is not part of `nix flake
check`.

## What it installs

- `ojuny-console.desktop`, session id `ojuny-console`. The standard
  `steam.desktop` is never written, replaced or claimed.
- A gamescope wrapper running
  `steam -steamos -pipewire-dmabuf -gamepadui`.
- Millennium with a generated Big Picture theme, when enabled.
- `ojuny-console-settings`, a GTK4 controller-first frontend over
  `nix-settings-backend`.
- An idempotent non-Steam shortcut for the frontend in Steam's
  `shortcuts.vdf`.

## Requirements

- NixOS or Home Manager with flakes enabled.
- Steam from nixpkgs, with unfree packages allowed.
- gamescope and a Wayland display manager.
- A Steam account. The repository does not store one.
- A configuration directory with `@menu` and `@option` annotations for the
  settings frontend.

## Install on NixOS

```nix
{
  inputs.ojuny-console-desktop.url = "github:ojuny-project/ojuny-console-desktop";

  outputs = { nixpkgs, ojuny-console-desktop, ... }: {
    nixosConfigurations.console = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ojuny-console-desktop.nixosModules.default
        {
          nixpkgs.config.allowUnfree = true;

          desktop.ojuny.console = {
            enable = true;
            autoLogin.enable = true;
            autoLogin.user = "player";

            settings = {
              enable = true;
              root = "/home/player/repos/nix-flake";
            };

            millennium.enable = true;
          };
        }
      ];
    };
  };
}
```

Do not enable `programs.steam.gamescopeSession`. It writes `steam.desktop` and
claims the `steam` session id. The module refuses that configuration with an
assertion.

## Install with Home Manager

```nix
{
  imports = [ ojuny-console-desktop.homeManagerModules.default ];

  desktop.ojuny.console = {
    enable = true;
    settings.enable = true;
    settings.root = "/home/player/repos/nix-flake";
  };
}
```

Home Manager installs the session file under
`~/.local/share/wayland-sessions`. GDM and LightDM do not scan the user profile,
so link it into `/usr/share/wayland-sessions` or configure the display manager.
`autoLogin` and `power` are NixOS-only options.

## Configure

The settings frontend reads pages from the template's `@menu` annotations. Save
writes the files through the backend. If `settings.applyCommand` is set, the
frontend offers to run it after saving.

Every option and its default is in [docs/options.md](docs/options.md).

## Try the settings frontend

```sh
nix run github:ojuny-project/ojuny-console-desktop
```

The runner opens the frontend against the current directory.

## Tests

```sh
nix flake check
nix build .#test-vm-session
```

`nix flake check` covers evaluation, Python syntax, the settings imports, the
session desktop file, the theme, the theme config merge, the shortcut writer and
the annotation gate. `test-vm-session` builds a NixOS VM and checks that
`ojuny-console.desktop` exists and `steam.desktop` does not. It pulls Steam into
the VM closure.

## Limits

- Big Picture theming depends on Millennium and on Steam's internal class names.
  A Steam update can break the theme or the injector. Pin the flake inputs and
  keep `millennium.enable = false` as a recovery switch.
- The shortcut reconciler writes Steam userdata and skips the write while Steam
  is running.
- The frontend's apply command is not privileged. Use a polkit-backed helper in
  the template for unattended rebuilds.
- Text fields in the frontend need a keyboard. Use Steam+X for the on-screen
  keyboard.
- HDR and VRR depend on the GPU, kernel, Mesa and the display.
- No game compatibility guarantee, no Steam account handling, no hardware
  certification.

## Documentation

- [docs/options.md](docs/options.md): every option and its default.
- [docs/sessions.md](docs/sessions.md): session ids, launch path, auto-login.
- [docs/design.md](docs/design.md): repository and runtime design.
- [docs/controllers.md](docs/controllers.md): frontend key map and input path.
- [docs/recovery.md](docs/recovery.md): failure modes and recovery.
- [docs/steam-state.md](docs/steam-state.md): what Nix owns and what Steam owns.

## License

GPL-3.0.
