# Pi coding agent wrapper.
#
# Plugin descriptors declare external configuration files, environment defaults,
# and Nix runtime dependencies. Pi reads and installs packages from settings.json.
{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  plugins = import ./plugins { inherit pkgs; };
  pluginMetadata = {
    configFiles = lib.concatLists (lib.catAttrs "config" plugins);
    env = lib.foldl' (acc: env: acc // env) { } (lib.catAttrs "env" plugins);
    runtimePkgs = lib.concatLists (lib.catAttrs "runtimePkgs" plugins);
  };
  runtimePackages = [ pkgs.coreutils ] ++ pluginMetadata.runtimePkgs;
  runtimeBinPath = lib.makeBinPath runtimePackages;
  configFiles = [
    "settings.json"
    "themes/dracula.json"
  ] ++ pluginMetadata.configFiles;

  linkConfig = relativePath: ''
    if [ ! -f "$PI_CONFIG_DIR/${relativePath}" ]; then
      echo "pi: missing config file: $PI_CONFIG_DIR/${relativePath}" >&2
      exit 1
    fi
    mkdir -p "$PI_CODING_AGENT_DIR/$(dirname "${relativePath}")"
    rm -f "$PI_CODING_AGENT_DIR/${relativePath}"
    ln -s "$PI_CONFIG_DIR/${relativePath}" "$PI_CODING_AGENT_DIR/${relativePath}"
  '';
in
{
  imports = [ wlib.modules.default ];

  options = {
    agentDirDefault = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.pi/agent";
      example = "$HOME/.pi/agent-dev";
      description = ''
        Default writable Pi state directory. PI_CODING_AGENT_DIR takes precedence
        when it is already set in the environment.
      '';
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = toString ./config;
      example = "$PWD/config";
      description = ''
        Directory containing the base settings and plugin configuration files.
        PI_CONFIG_DIR takes precedence when it is already set in the environment.
      '';
    };
  };

  config = {
    package = lib.mkDefault pkgs.pi-coding-agent;
    unsetVar = lib.mkDefault [ "DEV" ];
    runtimePkgs = runtimePackages;
    envDefault = pluginMetadata.env // {
      PI_SKIP_VERSION_CHECK = "1";
    };

    runShell = [
      ''
        # Prefer the Nix-provided tools over same-named host executables.
        export PATH="${runtimeBinPath}:$PATH"
        export PI_CODING_AGENT_DIR="''${PI_CODING_AGENT_DIR:-${config.agentDirDefault}}"
        export PI_CONFIG_DIR="''${PI_CONFIG_DIR:-${config.configDir}}"
        if [ ! -d "$PI_CONFIG_DIR" ]; then
          echo "pi: config directory does not exist: $PI_CONFIG_DIR" >&2
          exit 1
        fi
        mkdir -p "$PI_CODING_AGENT_DIR"
        ${lib.concatMapStringsSep "\n" linkConfig configFiles}
      ''
    ];
  };
}
