{ ... }:
{
  flake.modules.nixos.ojuny-console-options = {
    imports = [ (import ../../lib/ojuny-options.nix) ];
  };
}
