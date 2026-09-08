# mkPi: build a customized pi package from declarative configuration.
# Analogous to nixvim's makeNixvim — you declare what you want,
# and it produces a ready-to-run pi binary.
#
# Usage:
#   mkPi {}                     # default config
#   mkPi { modules = [ ... ]; } # custom modules
{ pkgs }:
{
  settings ? import ./settings.nix,
  modules ? [
    ./pi-hashline.nix
    ./pi-fff.nix
    ./pi-web-access.nix
    ./pi-codex-search.nix
    ./pi-tool-display.nix
    ./theme.nix
  ],
}:
let
  lib = pkgs.lib;

  loaded = map import modules;

  # Collect npm package strings from modules that declare one.
  packages = map (m: m.package) (builtins.filter (m: m.package or null != null) loaded);

  # Find theme name from modules that declare one.
  themeModules = builtins.filter (m: m ? themeName) loaded;
  themeName = if themeModules != [ ] then (builtins.head themeModules).themeName else null;

  # Merge settings + packages + theme into settings.json content.
  fullSettings =
    settings
    // { inherit packages; }
    // lib.optionalAttrs (themeName != null) { theme = themeName; };

  # Modules that produce a config file (name + config).
  configModules = builtins.filter (m: m.name or null != null && m.config or null != null) loaded;

  # Build the read-only agent directory in the nix store.
  agentStore = pkgs.linkFarm "pi-agent-store" (
    [
      {
        name = "settings.json";
        path = pkgs.writeText "settings.json" (builtins.toJSON fullSettings);
      }
    ]
    ++ map (m: {
      name = m.name;
      path = pkgs.writeText (lib.replaceStrings [ "/" ] [ "-" ] m.name) (builtins.toJSON m.config);
    }) configModules
  );

  # Collect extra env vars from modules (e.g. PI_FFF_MODE).
  envModules = builtins.filter (m: m.env or null != null) loaded;
  envLines = lib.concatStringsSep "\n" (
    map (m:
      lib.concatStringsSep "\n" (
        map (k: "    export ${k}=${lib.escapeShellArg m.env.${k}}") (builtins.attrNames m.env)
      )
    ) envModules
  );

  # Symlink commands: link each store config file into the writable agent dir.
  linkLines = lib.concatStringsSep "\n" (
    map (m: ''
      mkdir -p "$PI_CODING_AGENT_DIR/$(dirname "${m.name}")"
      ln -sfn "${agentStore}/${m.name}" "$PI_CODING_AGENT_DIR/${m.name}"'') configModules
  );

in
pkgs.writeShellApplication {
  name = "pi";
  runtimeInputs = [
    pkgs.pi-coding-agent
    pkgs.coreutils
  ];
  text = ''
    # Resolve agent dir: use env override or default to ~/.pi/agent.
    export PI_CODING_AGENT_DIR="''${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
    export PI_SKIP_VERSION_CHECK=1
    export PI_OFFLINE=1
    ${envLines}

    # Symlink declarative config from the nix store into the writable agent dir.
    # Pi writes runtime state (sessions, auth, models) alongside these symlinks.
    mkdir -p "$PI_CODING_AGENT_DIR"
    ln -sfn "${agentStore}/settings.json" "$PI_CODING_AGENT_DIR/settings.json"
    ${linkLines}

    exec pi "$@"
  '';
  meta.mainProgram = "pi";
}
