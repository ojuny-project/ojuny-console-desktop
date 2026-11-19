{ self, ... }:
{
  flake.modules.nixos.ojuny-console =
    { config, lib, ... }:
    {
      imports = [ self.modules.nixos.ojuny-console-options ];

      config = lib.mkIf config.desktop.ojuny.console.enable {
        security.polkit.enable = lib.mkDefault true;
        programs.xwayland.enable = lib.mkDefault true;
        services.graphical-desktop.enable = lib.mkDefault true;
      };
    };
}
