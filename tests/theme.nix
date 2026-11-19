{ pkgs, lib }:
let
  colorLib = import ../lib/theme-colors.nix { inherit lib; };
  theme = (pkgs.callPackage ../packages/millennium-theme { }) {
    colors = colorLib.palette;
  };
  themeDir = "${theme}/share/millennium/themes/ojuny-console";
in
pkgs.runCommand "check-ojuny-console-theme"
  {
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    test -f ${themeDir}/skin.json
    test -f ${themeDir}/bigpicture.custom.css
    test -f ${themeDir}/webkit.css
    python3 -m json.tool ${themeDir}/skin.json > /dev/null
    grep -q '"UseDefaultPatches":true' ${themeDir}/skin.json
    grep -q '"Steam-WebKit":"webkit.css"' ${themeDir}/skin.json
    grep -q -- '--SystemAccentColor' ${themeDir}/bigpicture.custom.css
    grep -q -- 'color-scheme: dark' ${themeDir}/webkit.css
    touch $out
  ''
