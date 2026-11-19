{
  config = lib.mkMerge [
    {
      # @option widget = "switch"; label = "Example";
      services.example.enable = true;
    }
  ];
}
