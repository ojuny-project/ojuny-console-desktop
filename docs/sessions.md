# Sessions

## Gaming session

The module registers one session package with
`services.displayManager.sessionPackages`:

```text
/run/current-system/sw/share/wayland-sessions/ojuny-console.desktop
```

The desktop file carries `providedSessions = [ "ojuny-console" ]`. The Exec line
runs `ojuny-console-session`, which starts:

```text
gamescope --steam -f <display flags> -- steam -steamos -pipewire-dmabuf -gamepadui
```

The display flags come from `desktop.ojuny.console.display.*`.

## steam.desktop is untouched

The repository does not write, replace or claim `steam.desktop`. The
`programs.steam.gamescopeSession` option is refused by an assertion because it
emits that file and claims the `steam` session id.

If a configuration enables it, evaluation fails with a message pointing at this
rule. The fix is to disable the option, not to rename the generated file.

## Default session

`services.displayManager.defaultSession` is set to `desktop.ojuny.console.session.name`,
which defaults to `ojuny-console`.

## Desktop target

`desktop.ojuny.console.desktopSession` names the desktop session id. The
repository does not create it. The console template supplies it, usually from
`ojuny-desktop`.

## Auto-login

On NixOS, `autoLogin.enable` and `autoLogin.user` set
`services.displayManager.autoLogin`. When auto-login is disabled, the display
manager greeter is used.

A failed console session with auto-login can loop. Set
`session.recoveryCommand` or disable auto-login before relying on recovery.

## Exit behavior

When Steam exits with status 0, the session ends and the display manager
returns. When gamescope or Steam exits non-zero, the wrapper runs
`session.recoveryCommand` if it is set.
