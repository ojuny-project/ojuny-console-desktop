{ ... }:
{
  flake.modules.homeManager.ojuny-console-options = {
    imports = [ (import ../../lib/ojuny-options.nix) ];
  };
}
