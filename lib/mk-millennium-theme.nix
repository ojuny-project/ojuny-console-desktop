{ lib, pkgs }:
{
  name,
  colors,
  accent ? null,
}:
let
  colorLib = import ./theme-colors.nix { inherit lib; };
  accentColor = if accent != null then accent else colors.base0D;

  skin = pkgs.writeText "ojuny-console-skin.json" (
    builtins.toJSON {
      name = "Ojuny Console";
      author = "Ojuny";
      description = "Console theme for Ojuny, generated from the session palette.";
      version = "1.0.0";
      UseDefaultPatches = true;
      tags = [
        "Ojuny"
        "Console"
        "Dark"
      ];
      header_image = "header.svg";
      splash_image = "header.svg";
      "Steam-WebKit" = "webkit.css";
    }
  );

  css = pkgs.writeText "ojuny-console-bigpicture.css" (colorLib.mkCss colors accentColor);
  webkit = pkgs.writeText "ojuny-console-webkit.css" (colorLib.mkWebkitCss colors accentColor);

  header = pkgs.writeText "ojuny-console-header.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="920" height="430" viewBox="0 0 920 430">
      <rect width="920" height="430" fill="${colors.base00}"/>
      <text x="460" y="215" fill="${colors.base05}" font-family="sans-serif" font-size="96"
            text-anchor="middle" dominant-baseline="middle">Ojuny</text>
      <text x="460" y="300" fill="${colors.base04}" font-family="sans-serif" font-size="34"
            text-anchor="middle" dominant-baseline="middle">Console</text>
    </svg>
  '';
in
pkgs.runCommand "ojuny-console-theme-${name}" { } ''
  theme="$out/share/millennium/themes/${name}"
  mkdir -p "$theme"
  cp ${skin} "$theme/skin.json"
  cp ${css} "$theme/bigpicture.custom.css"
  cp ${webkit} "$theme/webkit.css"
  cp ${header} "$theme/header.svg"
''
