{ self, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    {
      checks = {
        session = import ../../tests/session.nix { inherit pkgs lib; };
        theme = import ../../tests/theme.nix { inherit pkgs lib; };
        theme-config = import ../../tests/theme-config.nix { inherit pkgs; };
        steam-shortcut = import ../../tests/steam-shortcut.nix { inherit pkgs; };
        settings-python = import ../../tests/settings-python.nix { inherit pkgs; };
        settings-import = import ../../tests/settings-import.nix {
          inherit pkgs;
          settings = self.packages.${system}.ojuny-console-settings;
        };
      };
    };
}
