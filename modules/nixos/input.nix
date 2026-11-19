{ ... }:
{
  flake.modules.nixos.ojuny-console =
    { config, lib, ... }:
    let
      cfg = config.desktop.ojuny.console;
    in
    {
      config = lib.mkIf cfg.enable {
        services.udev.extraRules = cfg.input.extraUdevRules;
      };
    };
}
