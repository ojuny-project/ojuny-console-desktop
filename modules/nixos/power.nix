{ ... }:
{
  flake.modules.nixos.ojuny-console =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      cfg = config.desktop.ojuny.console;
    in
    {
      config = lib.mkIf cfg.enable {
        services.logind.settings = lib.mkIf (options.services.logind ? settings) {
          Login = {
            IdleAction = if cfg.power.idleAction == null then "ignore" else cfg.power.idleAction;
            IdleActionSec = "${toString cfg.power.idleDelay}s";
            HandleLidSwitch = cfg.power.lidSwitch;
          };
        };
      };
    };
}
