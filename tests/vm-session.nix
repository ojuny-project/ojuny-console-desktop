{ pkgs, module }:
let
  testPkgs = import pkgs.path {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
testPkgs.testers.nixosTest {
  name = "ojuny-console-session";

  nodes.machine =
    { ... }:
    {
      imports = [ module ];

      system.stateVersion = "26.05";

      fileSystems."/" = {
        device = "/dev/vda1";
        fsType = "ext4";
      };

      users.users.player = {
        isNormalUser = true;
      };

      desktop.ojuny.console = {
        enable = true;
        autoLogin = {
          enable = true;
          user = "player";
        };
      };
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("test -f /run/current-system/sw/share/wayland-sessions/ojuny-console.desktop")
    machine.fail("test -e /run/current-system/sw/share/wayland-sessions/steam.desktop")
    machine.succeed("grep -q 'ojuny-console-session' /run/current-system/sw/share/wayland-sessions/ojuny-console.desktop")
  '';
}
