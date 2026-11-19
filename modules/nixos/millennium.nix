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
      colorLib = import ../../lib/theme-colors.nix { inherit lib; };
      colors =
        if options ? stylix then colorLib.fromStylix config.lib.stylix.colors else colorLib.palette;

      theme = (pkgs.callPackage ../../packages/millennium-theme { }) {
        name = cfg.millennium.name;
        inherit colors;
        accent = cfg.millennium.accent;
      };

      enroll = pkgs.writeShellApplication {
        name = "ojuny-console-theme";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.python3
        ];
        text = ''
          theme_dir="$1"
          theme_name="$2"
          steam_dir="''${STEAM_DIR:-$HOME/.steam/steam}"
          config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/millennium"
          state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/ojuny-console"

          if [ ! -d "$steam_dir" ]; then
            echo "Steam has not been started yet; theme enrollment skipped." >&2
            exit 0
          fi

          mkdir -p "$steam_dir/millennium/themes" "$config_dir" "$state_dir"
          ln -sfnT "$theme_dir" "$steam_dir/millennium/themes/$theme_name"
          python3 ${../../lib/theme-config.py} "$config_dir/config.json" "$theme_name" "$state_dir/theme-enrolled"
        '';
      };

      themeService = pkgs.writeShellApplication {
        name = "ojuny-console-theme-service";
        text = ''
          exec ${enroll}/bin/ojuny-console-theme ${lib.escapeShellArg (toString theme)} ${lib.escapeShellArg cfg.millennium.name}
        '';
      };
    in
    {
      config = lib.mkIf (cfg.enable && cfg.millennium.enable && cfg.millennium.theme) {
        systemd.user.services.ojuny-console-theme = {
          description = "Enroll the Ojuny Console Millennium theme";
          wantedBy = [ "default.target" ];
          before = [ "graphical-session.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${themeService}/bin/ojuny-console-theme-service";
          };
          restartTriggers = [
            theme
            themeService
          ];
        };
      };
    };
}
