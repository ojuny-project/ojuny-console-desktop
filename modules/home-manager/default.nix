{ self, inputs, ... }:
{
  flake.modules.homeManager.ojuny-console =
    {
      config,
      lib,
      options,
      pkgs,
      ...
    }:
    let
      cfg = config.desktop.ojuny.console;
      system = pkgs.stdenv.hostPlatform.system;

      millenniumPkgs = pkgs.extend inputs.millennium.overlays.default;

      steamPackage =
        if cfg.steam.package != null then
          cfg.steam.package
        else if cfg.millennium.enable then
          millenniumPkgs.millennium-steam
        else
          pkgs.steam;

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

      sessionWrapper = (pkgs.callPackage ../../packages/console-session { }) {
        name = "ojuny-console-session";
        steam = steamPackage;
        steamArgs = cfg.session.steamArgs ++ cfg.steam.extraArgs;
        inherit gamescopeArgs;
        recoveryCommand = cfg.session.recoveryCommand;
      };

      session = (import ../../lib/mk-session.nix { inherit lib pkgs; }) {
        name = cfg.session.name;
        comment = "Ojuny Console (Steam Big Picture, Home Manager)";
        exec = "${sessionWrapper}/bin/ojuny-console-session";
      };

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
      imports = [ self.modules.homeManager.ojuny-console-options ];

      config = lib.mkIf cfg.enable {
        home.packages = [
          pkgs.gamescope
          steamPackage
        ]
        ++ lib.optional cfg.settings.enable settingsPackage
        ++ lib.optional (cfg.settings.enable && cfg.settings.root != null) settingsWrapper;

        home.file.".local/share/wayland-sessions/${cfg.session.name}.desktop".source =
          "${session}/share/wayland-sessions/${cfg.session.name}.desktop";

        home.sessionVariables =
          lib.optionalAttrs (cfg.audio.sink != null) { PULSE_SINK = cfg.audio.sink; }
          // lib.optionalAttrs (cfg.audio.channelLayout != null) {
            PULSE_CHANNEL_MAP = cfg.audio.channelLayout;
          }
          // {
            NIXOS_OZONE_WL = "1";
          };

        systemd.user.services.ojuny-console-theme =
          lib.mkIf (cfg.millennium.enable && cfg.millennium.theme)
            {
              Unit = {
                Description = "Enroll the Ojuny Console Millennium theme";
                Before = [ "graphical-session.target" ];
              };
              Service = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = "${themeService}/bin/ojuny-console-theme-service";
              };
              Install.WantedBy = [ "default.target" ];
            };

        systemd.user.services.ojuny-console-shortcut =
          lib.mkIf (cfg.settings.enable && cfg.shortcut.enable && cfg.settings.root != null)
            {
              Unit = {
                Description = "Add the Ojuny Console settings shortcut to Steam";
                Before = [ "graphical-session.target" ];
              };
              Service = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = "${shortcutService}/bin/ojuny-console-shortcut-service";
              };
              Install.WantedBy = [ "default.target" ];
            };

        assertions = [
          {
            assertion = cfg.session.name != "steam";
            message = "desktop.ojuny.console.session.name must not be \"steam\"; that session id belongs to steam.desktop.";
          }
        ];
      };
    };
}
