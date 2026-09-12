# Pi coding agent — Nix runtime wrapper.
#
# Nix provides the executable and stable runtime dependencies (node, npm, rg,
# git, …). Extension installation, settings.json, and plugin configs are owned
# by Pi itself (~/.pi/agent/).
{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  integrations = import ./integrations { inherit pkgs; };

  integrationMetadata = {
    env = lib.foldl' (acc: env: acc // env) { } (lib.catAttrs "env" integrations);
    runtimePkgs = lib.concatLists (lib.catAttrs "runtimePkgs" integrations);
  };

  runtimePackages = [
    pkgs.coreutils
    pkgs.nodejs
  ] ++ integrationMetadata.runtimePkgs;

  configFiles = [
    "settings.json"
    "pi-fff.json"
    "hashline.json"
    "claude-code-style.json"
    "web-search.json"
  ];
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
        Directory containing configuration files. Used as the source for
        bootstrapping or symlinking into the Pi agent directory.
      '';
    };

    configMode = lib.mkOption {
      type = lib.types.enum [ "mutable" "seed" ];
      default = "seed";
      example = "mutable";
      description = ''
        How to handle configuration files:
        - mutable: symlink from configDir (changes persist to source)
        - seed: bootstrap copy from configDir (only if file missing)
      '';
    };
  };

  config = {
    package = lib.mkDefault pkgs.pi-coding-agent;
    unsetVar = lib.mkDefault [ "DEV" ];
    runtimePkgs = map (pkg: { data = pkg; prefix = true; }) runtimePackages;
    envDefault = integrationMetadata.env // {
      PI_SKIP_VERSION_CHECK = "1";
    };

    runShell = [
      ''
        export PI_CODING_AGENT_DIR="''${PI_CODING_AGENT_DIR:-${config.agentDirDefault}}"
        mkdir -p "$PI_CODING_AGENT_DIR"

        # Config file management (${config.configMode} mode)
        PI_CONFIG_DIR="${config.configDir}"
        if [ -d "$PI_CONFIG_DIR" ]; then
          for file in ${lib.concatStringsSep " " configFiles}; do
            target="$PI_CODING_AGENT_DIR/$file"
            source="$PI_CONFIG_DIR/$file"
            if [ -f "$source" ]; then
              if [ "${config.configMode}" = "mutable" ]; then
                # Mutable mode: symlink (changes persist to source)
                if [ -L "$target" ]; then
                  rm "$target"
                elif [ -e "$target" ]; then
                  echo "pi: refusing to replace non-symlink config: $target" >&2
                  exit 1
                fi
                ln -s "$source" "$target"
              else
                # Seed mode: bootstrap copy (only if missing)
                if [ ! -e "$target" ]; then
                  cp "$source" "$target"
                  chmod u+w "$target"
                fi
              fi
            fi
          done
        fi
      ''
    ];
  };
}
