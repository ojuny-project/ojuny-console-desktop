{ lib }:
let
  defaults = import ./defaults.nix;

  keys = [
    "base00"
    "base01"
    "base02"
    "base03"
    "base04"
    "base05"
    "base06"
    "base07"
    "base08"
    "base09"
    "base0A"
    "base0B"
    "base0C"
    "base0D"
    "base0E"
    "base0F"
  ];

  withHash = value: if lib.hasPrefix "#" value then value else "#${value}";

  fromStylix = colors: lib.genAttrs keys (key: withHash colors.${key});

  mkCss = colors: accent: ''
    :root {
      --SystemAccentColor: ${accent};
      --SystemAccentColorLight1: ${colors.base0C};
      --SystemAccentColorDark1: ${colors.base0E};
      --ojuny-background: ${colors.base00};
      --ojuny-surface: ${colors.base01};
      --ojuny-text: ${colors.base05};
      --ojuny-muted: ${colors.base04};
    }

    body,
    .BasicUI {
      background-color: var(--ojuny-background) !important;
      color: var(--ojuny-text) !important;
    }

    .Focusable:focus,
    .gpfocus,
    .gpfocuswithin {
      outline: 2px solid var(--SystemAccentColor) !important;
    }

    .DialogButton,
    .Panel {
      background-color: var(--ojuny-surface) !important;
      color: var(--ojuny-text) !important;
    }
  '';

  mkWebkitCss = colors: accent: ''
    :root {
      color-scheme: dark;
      --SystemAccentColor: ${accent};
    }

    html,
    body {
      background-color: ${colors.base00} !important;
      color: ${colors.base05} !important;
    }

    a,
    a:hover,
    a:visited {
      color: ${colors.base0D} !important;
    }

    input,
    textarea,
    select,
    button {
      background-color: ${colors.base01} !important;
      color: ${colors.base05} !important;
      border-color: ${colors.base03} !important;
    }

    ::selection {
      background-color: ${colors.base0D} !important;
      color: ${colors.base00} !important;
    }
  '';
in
{
  inherit
    keys
    withHash
    fromStylix
    mkCss
    mkWebkitCss
    ;
  inherit (defaults) palette;
}
