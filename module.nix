# Pi coding agent — Nix runtime wrapper.
#
# Nix provides the executable and stable runtime dependencies (node, npm, rg,
# git, …). Config files are symlinked from configDir (git working tree) into
# the Pi agent directory, allowing direct modification and git diff.
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
  };

  config = {
    package = lib.mkDefault pkgs.pi-coding-agent;
    runtimePkgs = map (pkg: { data = pkg; prefix = true; }) runtimePackages;
    envDefault.PI_SKIP_VERSION_CHECK = "1";

    runShell = [
      ''
        export PI_CODING_AGENT_DIR="''${PI_CODING_AGENT_DIR:-${config.agentDirDefault}}"
        mkdir -p "$PI_CODING_AGENT_DIR"

        # Config file management — symlink from configDir (git working tree)
        PI_CONFIG_DIR="${config.configDir}"
        if [ -d "$PI_CONFIG_DIR" ]; then
          for file in ${lib.concatStringsSep " " configFiles}; do
            target="$PI_CODING_AGENT_DIR/$file"
            source="$PI_CONFIG_DIR/$file"
            if [ -f "$source" ]; then
              if [ -L "$target" ]; then
                rm "$target"
              elif [ -e "$target" ]; then
                backup="$target.pre-nixpi-link.$(date +%s)"
                mv "$target" "$backup"
                echo "pi: moved existing config to backup: $backup" >&2
              fi
              ln -s "$source" "$target"
            fi
          done
        fi
      ''
    ];
  };
}
