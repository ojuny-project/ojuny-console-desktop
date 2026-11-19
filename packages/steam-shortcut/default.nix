{
  python3,
  procps,
  writeShellApplication,
}:
writeShellApplication {
  name = "ojuny-console-shortcut";

  runtimeInputs = [
    python3
    procps
  ];

  text = ''
    exec python3 ${./ojuny-steam-shortcut.py} "$@"
  '';
}
