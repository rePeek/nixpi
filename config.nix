# Aggregates all plugin/theme modules into an agent directory derivation.
# Each module file returns { name, config, package, env? }.
{ pkgs }:
let
  modules = [
    (import ./pi-hashline.nix)
    (import ./pi-fff.nix)
    (import ./pi-web-access.nix)
    (import ./pi-codex-search.nix)
    (import ./pi-tool-display.nix)
    (import ./theme.nix)
  ];

  settings = import ./settings.nix;

  # Collect all npm packages from modules that declare one.
  packages = map (m: m.package) (builtins.filter (m: m.package != null) modules);

  # Merge settings with the packages list and theme name.
  themeModule = builtins.head (builtins.filter (m: m ? themeName) modules);
  fullSettings = settings // {
    inherit packages;
    theme = themeModule.themeName;
  };

  # Build linkFarm entries from modules that have a config file.
  configEntries =
    map
      (m: {
        name = m.name;
        path = pkgs.writeText (builtins.replaceStrings [ "/" ] [ "-" ] m.name) (
          builtins.toJSON m.config
        );
      })
      (builtins.filter (m: m.config != null) modules);

in
pkgs.linkFarm "pi-agent" (
  [
    {
      name = "settings.json";
      path = pkgs.writeText "settings.json" (builtins.toJSON fullSettings);
    }
  ]
  ++ configEntries
)
