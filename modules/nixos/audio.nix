{ ... }:
{
  flake.modules.nixos.ojuny-console =
    { config, lib, ... }:
    let
      cfg = config.desktop.ojuny.console;
    in
    {
      config = lib.mkIf cfg.enable {
        environment.sessionVariables =
          lib.optionalAttrs (cfg.audio.sink != null) {
            PULSE_SINK = cfg.audio.sink;
          }
          // lib.optionalAttrs (cfg.audio.channelLayout != null) {
            PULSE_CHANNEL_MAP = cfg.audio.channelLayout;
          };
      };
    };
}
