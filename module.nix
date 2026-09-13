# Pi coding agent — Nix runtime wrapper.
#
# Nix provides the executable and stable runtime dependencies (node, npm, rg,
# git, …). At runtime, config files are symlinked from the mutable checkout
# into ~/.pi/agent/, allowing direct modification and git diff.
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

  storeConfigDir = toString ./config;
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

        # A Nix path such as ./config is copied into /nix/store during
        # evaluation, so it cannot be the mutable source of these links. Use
        # the checkout path at runtime; callers with a different checkout can
        # override it with NIXPI_CONFIG_DIR. The store snapshot is a fallback
        # only for installations that deliberately have no checkout.
        PI_CONFIG_DIR="''${NIXPI_CONFIG_DIR:-$HOME/nixos-config/components/nixpi/config}"
        if [ ! -d "$PI_CONFIG_DIR" ]; then
          echo "pi: nixpi checkout config not found; using immutable store snapshot" >&2
          PI_CONFIG_DIR="${storeConfigDir}"
        fi

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
      ''
    ];
  };
}
