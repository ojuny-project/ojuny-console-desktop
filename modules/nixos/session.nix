{ ... }:
{
  flake.modules.nixos.ojuny-console =
    {
      config,
      lib,
      pkgs,
      options,
      ...
    }:
    let
      cfg = config.desktop.ojuny.console;

      gamescopeArgs = [
        "--steam"
        "-f"
      ]
      ++ lib.optional cfg.display.hdr "--hdr-enabled"
      ++ lib.optional cfg.display.vrr "--adaptive-sync"
      ++ lib.optionals (cfg.display.width != null) [
        "-W"
        (toString cfg.display.width)
      ]
      ++ lib.optionals (cfg.display.height != null) [
        "-H"
        (toString cfg.display.height)
      ]
      ++ lib.optionals (cfg.display.refresh != null) [
        "-r"
        (toString cfg.display.refresh)
      ]
      ++ cfg.session.extraGamescopeArgs;

      sessionWrapper = (pkgs.callPackage ../../packages/console-session { gamescope = null; }) {
        name = "ojuny-console-session";
        steam = config.programs.steam.package;
        steamArgs = cfg.session.steamArgs ++ cfg.steam.extraArgs;
        inherit gamescopeArgs;
        recoveryCommand = cfg.session.recoveryCommand;
      };

      session = (import ../../lib/mk-session.nix { inherit lib pkgs; }) {
        name = cfg.session.name;
        comment = "Ojuny Console (Steam Big Picture)";
        exec = "${sessionWrapper}/bin/ojuny-console-session";
      };
    in
    {
      config = lib.mkIf cfg.enable {
        services.displayManager.sessionPackages = [ session ];
        services.displayManager.defaultSession = lib.mkDefault cfg.session.name;

        services.displayManager.autoLogin = lib.mkIf cfg.autoLogin.enable {
          enable = true;
          user = cfg.autoLogin.user;
        };

        assertions = [
          {
            assertion =
              !(options ? programs.steam.gamescopeSession) || !config.programs.steam.gamescopeSession.enable;
            message = ''
              desktop.ojuny.console uses its own ojuny-console.desktop session.
              Disable programs.steam.gamescopeSession; it writes steam.desktop
              and claims the steam session id.
            '';
          }
          {
            assertion = !cfg.autoLogin.enable || cfg.autoLogin.user != null;
            message = "desktop.ojuny.console.autoLogin.user must be set when autoLogin is enabled.";
          }
          {
            assertion = cfg.session.name != "steam";
            message = "desktop.ojuny.console.session.name must not be \"steam\"; that session id belongs to steam.desktop.";
          }
        ];
      };
    };
}
