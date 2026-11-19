{ inputs, ... }:
{
  flake.modules.nixos.ojuny-console =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.desktop.ojuny.console;
    in
    {
      config = lib.mkIf cfg.enable {
        nixpkgs.overlays = lib.mkIf cfg.millennium.enable [
          inputs.millennium.overlays.default
        ];

        programs.steam = {
          enable = lib.mkDefault true;

          package = lib.mkDefault (
            if cfg.steam.package != null then
              cfg.steam.package
            else if cfg.millennium.enable then
              pkgs.millennium-steam
            else
              pkgs.steam
          );

          extraCompatPackages = cfg.steam.extraCompatPackages;
          remotePlay.openFirewall = cfg.steam.remotePlay;
        };

        hardware.steam-hardware.enable = lib.mkDefault cfg.input.steamHardware;
        environment.sessionVariables.NIXOS_OZONE_WL = lib.mkDefault "1";
      };
    };
}
