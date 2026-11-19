{ lib, pkgs }:
{
  name ? "ojuny-console",
  colors,
  accent ? null,
}:
import ../../lib/mk-millennium-theme.nix { inherit lib pkgs; } {
  inherit name colors accent;
}
