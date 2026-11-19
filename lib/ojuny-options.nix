{ lib, ... }:
let
  defaults = import ./defaults.nix;

  inherit (lib) mkEnableOption mkOption types;

  powerActions = [
    "ignore"
    "poweroff"
    "reboot"
    "halt"
    "suspend"
    "hibernate"
    "hybrid-sleep"
    "suspend-then-hibernate"
    "lock"
    "kexec"
  ];
in
{
  options.desktop.ojuny.console = {
    enable = mkEnableOption "the Ojuny console session layer";

    desktopSession = mkOption {
      type = types.str;
      default = "ojuny";
      description = ''
        Session id of the desktop target. This repository never creates or
        edits that session, and never replaces steam.desktop.
      '';
    };

    autoLogin = {
      enable = mkEnableOption "automatic login for the console account";

      user = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Account that is logged in automatically.";
      };
    };

    steam = {
      package = mkOption {
        type = types.nullOr types.package;
        default = null;
        description = ''
          Steam package. Null selects millennium-steam when Millennium is
          enabled, otherwise pkgs.steam.
        '';
      };

      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Extra arguments passed to Steam in the console session.";
      };

      extraCompatPackages = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "Additional Steam compatibility tools.";
      };

      remotePlay = mkOption {
        type = types.bool;
        default = false;
        description = "Open the Steam Remote Play firewall ports.";
      };
    };

    session = {
      name = mkOption {
        type = types.str;
        default = "ojuny-console";
        description = "Wayland session id and desktop file name.";
      };

      steamArgs = mkOption {
        type = types.listOf types.str;
        default = defaults.steamArgs;
        description = "Arguments passed to Steam by the session wrapper.";
      };

      extraGamescopeArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Extra arguments appended to the gamescope command.";
      };

      recoveryCommand = mkOption {
        type = types.str;
        default = "";
        description = ''
          Command run when the gaming session exits with a non-zero status.
          Empty leaves recovery to the display manager.
        '';
      };
    };

    display = {
      hdr = mkOption {
        type = types.bool;
        default = false;
        description = "Enable gamescope HDR output.";
      };

      vrr = mkOption {
        type = types.bool;
        default = false;
        description = "Enable gamescope adaptive sync.";
      };

      width = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Gamescope output width. Null uses the display mode.";
      };

      height = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Gamescope output height. Null uses the display mode.";
      };

      refresh = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Gamescope refresh rate. Null uses the display mode.";
      };
    };

    audio = {
      sink = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "PipeWire or PulseAudio sink name exported as PULSE_SINK.";
      };

      channelLayout = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Channel layout exported as PULSE_CHANNEL_MAP.";
      };
    };

    input = {
      steamHardware = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Steam controller hardware support.";
      };

      extraUdevRules = mkOption {
        type = types.lines;
        default = "";
        description = "Additional udev rules for controllers and remotes.";
      };
    };

    power = {
      idleAction = mkOption {
        type = types.nullOr (types.enum powerActions);
        default = "ignore";
        description = "Logind idle action for the console account.";
      };

      idleDelay = mkOption {
        type = types.int;
        default = 300;
        description = "Seconds of inactivity before the logind idle action runs.";
      };

      lidSwitch = mkOption {
        type = types.enum powerActions;
        default = "ignore";
        description = "Logind action for the lid switch.";
      };
    };

    millennium = {
      enable = mkEnableOption "Millennium and the Ojuny Big Picture theme";

      theme = mkOption {
        type = types.bool;
        default = true;
        description = "Install and enroll the generated Big Picture theme.";
      };

      name = mkOption {
        type = types.str;
        default = "ojuny-console";
        description = "Theme directory name and active theme key.";
      };

      accent = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "CSS color for the focus accent. Null uses base0D.";
      };
    };

    settings = {
      enable = mkEnableOption "the console settings frontend";

      root = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Flake or configuration directory the settings frontend edits. The
          Steam shortcut is only installed when this is set.
        '';
      };

      applyCommand = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Command the frontend runs after saving. Null leaves the rebuild to
          the user.
        '';
      };

      package = mkOption {
        type = types.nullOr types.package;
        default = null;
        description = "Override the console settings frontend package.";
      };
    };

    shortcut = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Add the settings frontend as a non-Steam shortcut.";
      };

      name = mkOption {
        type = types.str;
        default = "Ojuny Settings";
        description = "Name shown in the Steam library.";
      };
    };
  };
}
