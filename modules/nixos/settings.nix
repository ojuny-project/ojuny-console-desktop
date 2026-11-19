{ inputs, ... }:
{
  flake.modules.nixos.ojuny-console =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.desktop.ojuny.console;
      system = pkgs.stdenv.hostPlatform.system;

      settingsPackage =
        if cfg.settings.package != null then
          cfg.settings.package
        else
          pkgs.callPackage ../../packages/console-settings {
            nix-settings-gui = inputs.nix-settings-gui.packages.${system}.nix-settings-gui;
          };

      settingsWrapper = pkgs.writeShellApplication {
        name = "ojuny-console-settings";
        text = ''
          export OJUNY_CONSOLE_SETTINGS_ROOT=${lib.escapeShellArg (toString cfg.settings.root)}
          ${lib.optionalString (cfg.settings.applyCommand != null) ''
            export OJUNY_CONSOLE_SETTINGS_APPLY_COMMAND=${lib.escapeShellArg cfg.settings.applyCommand}
          ''}
          exec ${settingsPackage}/bin/ojuny-console-settings "$@"
        '';
      };

      shortcut = pkgs.callPackage ../../packages/steam-shortcut { };

      shortcutService = pkgs.writeShellApplication {
        name = "ojuny-console-shortcut-service";
        text = ''
          exec ${shortcut}/bin/ojuny-console-shortcut \
            --name ${lib.escapeShellArg cfg.shortcut.name} \
            --exe ${settingsWrapper}/bin/ojuny-console-settings
        '';
      };
    in
    {
      config = lib.mkIf cfg.enable {
        environment.systemPackages =
          lib.optional cfg.settings.enable settingsPackage
          ++ lib.optional (cfg.settings.enable && cfg.settings.root != null) settingsWrapper;

        systemd.user.services.ojuny-console-shortcut =
          lib.mkIf (cfg.settings.enable && cfg.shortcut.enable && cfg.settings.root != null)
            {
              description = "Add the Ojuny Console settings shortcut to Steam";
              wantedBy = [ "default.target" ];
              before = [ "graphical-session.target" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = "${shortcutService}/bin/ojuny-console-shortcut-service";
              };
              restartTriggers = [
                settingsWrapper
                shortcutService
              ];
            };
      };
    };
}
