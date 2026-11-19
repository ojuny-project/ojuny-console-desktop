{ self, inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      colorLib = import ../../lib/theme-colors.nix { inherit (pkgs) lib; };

      session = (pkgs.callPackage ../../packages/console-session { }) { };

      settings = pkgs.callPackage ../../packages/console-settings {
        nix-settings-gui = inputs.nix-settings-gui.packages.${system}.nix-settings-gui;
      };

      run = pkgs.writeShellApplication {
        name = "ojuny-console-settings-run";
        text = ''
          exec ${settings}/bin/ojuny-console-settings --root "$PWD" "$@"
        '';
      };
    in
    {
      packages = {
        ojuny-console-session = session;
        ojuny-console-theme = (pkgs.callPackage ../../packages/millennium-theme { }) {
          colors = colorLib.palette;
        };
        ojuny-console-shortcut = pkgs.callPackage ../../packages/steam-shortcut { };
        ojuny-console-settings = settings;
        test-vm-session = import ../../tests/vm-session.nix {
          inherit pkgs;
          module = self.nixosModules.default;
        };
        default = session;
      };

      apps.run = {
        type = "app";
        program = "${run}/bin/ojuny-console-settings-run";
        meta.description = "Run the Ojuny Console settings frontend against the current directory";
      };
    };
}
