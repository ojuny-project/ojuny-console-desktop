{ ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    {
      checks.option-annotation-placement = import ../../tests/annotation-placement.nix {
        inherit pkgs lib;
      };
    };
}
