{ ... }:
{
  flake.modules.nixos.ojuny-console =
    { config, lib, ... }:
    {
      config = lib.mkIf config.desktop.ojuny.console.enable {
        programs.gamescope.enable = true;
        hardware.graphics.enable = lib.mkDefault true;
        hardware.graphics.enable32Bit = lib.mkDefault true;
      };
    };
}
