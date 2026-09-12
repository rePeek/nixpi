# Pi coding agent — Nix runtime wrapper.
#
# Nix provides the executable and stable runtime dependencies (node, npm, rg,
# git, …). Config files are symlinked into the Pi agent directory.
#
# Two modes:
# - mutable (default): symlink from configDir (git working tree), Pi can modify directly
# - immutable: symlink from Nix store snapshot, read-only
{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  runtimePackages = [
    pkgs.coreutils
    pkgs.nodejs
    pkgs.git
  ];

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
      example = "$HOME/.pi/agent";
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
        symlinks into the Pi agent directory.
      '';
    };

    configMode = lib.mkOption {
      type = lib.types.enum [ "mutable" "immutable" ];
      default = "mutable";
      example = "immutable";
      description = ''
        How to handle configuration files:
        - mutable: symlink from configDir (usually git working tree), Pi can modify directly
        - immutable: symlink from Nix store snapshot, read-only
      '';
    };
  };

  config = {
    package = lib.mkDefault pkgs.pi-coding-agent;
    unsetVar = lib.mkDefault [ "DEV" ];
    runtimePkgs = map (pkg: { data = pkg; prefix = true; }) runtimePackages;
    envDefault.PI_SKIP_VERSION_CHECK = "1";

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
              if [ -L "$target" ]; then
                rm "$target"
              elif [ -e "$target" ]; then
                if [ "${config.configMode}" = "immutable" ]; then
                  backup="$target.pre-nixpi-link.$(date +%s)"
                  mv "$target" "$backup"
                  echo "pi: moved existing config to backup: $backup" >&2
                else
                  echo "pi: refusing to replace non-symlink config: $target" >&2
                  exit 1
                fi
              fi
              ln -s "$source" "$target"
            fi
          done
        fi
      ''
    ];
  };
}
