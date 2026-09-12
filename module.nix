# Pi coding agent — Nix runtime wrapper.
#
# Nix provides the executable and stable runtime dependencies (node, npm, rg,
# git, …). Config files are symlinked from ./config (git working tree) into
# ~/.pi/agent/, allowing direct modification and git diff.
{
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

  configDir = toString ./config;
in
{
  imports = [ wlib.modules.default ];

  config = {
    package = lib.mkDefault pkgs.pi-coding-agent;
    runtimePkgs = map (pkg: { data = pkg; prefix = true; }) runtimePackages;
    envDefault.PI_SKIP_VERSION_CHECK = "1";

    runShell = [
      ''
        export PI_CODING_AGENT_DIR="''${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
        mkdir -p "$PI_CODING_AGENT_DIR"

        # Config file management — symlink from ./config (git working tree)
        PI_CONFIG_DIR="${configDir}"
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
