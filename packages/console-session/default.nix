{
  lib,
  writeShellApplication,
  gamescope,
}:
{
  name ? "ojuny-console-session",
  steam ? null,
  steamArgs ? [
    "-steamos"
    "-pipewire-dmabuf"
    "-gamepadui"
  ],
  gamescopeArgs ? [
    "--steam"
    "-f"
  ],
  recoveryCommand ? "",
}:
let
  steamBin = if steam == null then "steam" else "${steam}/bin/steam";
  gamescopeBin = if gamescope == null then "gamescope" else "${gamescope}/bin/gamescope";

  recovery = lib.optionalString (recoveryCommand != "") ''
    if [ "$status" -ne 0 ]; then
      ${recoveryCommand}
    fi
  '';
in
writeShellApplication {
  inherit name;

  runtimeInputs = lib.optional (gamescope != null) gamescope ++ lib.optional (steam != null) steam;

  text = ''
    set +e
    ${gamescopeBin} ${lib.escapeShellArgs gamescopeArgs} -- ${steamBin} ${lib.escapeShellArgs steamArgs}
    status=$?
    set -e

    ${recovery}

    exit "$status"
  '';
}
