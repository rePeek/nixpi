# Pi coding agent wrapper.
#
# Nix wraps the pi executable. All pi and plugin configuration is plain content
# under ./config: the default package uses its immutable store snapshot, while
# pi-dev reads ./config from the current working directory.
{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  configFiles = [
    "settings.json"
    "hashline.json"
    "web-search.json"
    "pi-codex-search.json"
    "extensions/pi-tool-display/config.json"
    "themes/dracula.json"
  ];

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
        Default writable pi state directory. PI_CODING_AGENT_DIR takes precedence
        when it is already set in the environment.
      '';
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = toString ./config;
      example = "$PWD/config";
      description = ''
        Directory containing settings.json and plugin configuration files.
        PI_CONFIG_DIR takes precedence when it is already set in the environment.
      '';
    };
  };

  config = {
    package = lib.mkDefault pkgs.pi-coding-agent;
    unsetVar = lib.mkDefault [ "DEV" ];
    runtimePkgs = [ pkgs.coreutils ];

    # Wrapper policy; plugin-specific variables belong in config/env.sh.
    envDefault = {
      PI_SKIP_VERSION_CHECK = "1";
      PI_OFFLINE = "1";
    };

    runShell = [
      ''
        export PI_CODING_AGENT_DIR="''${PI_CODING_AGENT_DIR:-${config.agentDirDefault}}"
        export PI_CONFIG_DIR="''${PI_CONFIG_DIR:-${config.configDir}}"
        if [ ! -d "$PI_CONFIG_DIR" ]; then
          echo "pi: config directory does not exist: $PI_CONFIG_DIR" >&2
          exit 1
        fi
        if [ -f "$PI_CONFIG_DIR/env.sh" ]; then
          . "$PI_CONFIG_DIR/env.sh"
        fi
        mkdir -p "$PI_CODING_AGENT_DIR"
        ${lib.concatMapStringsSep "\n" linkConfig configFiles}
      ''
    ];
  };
}
