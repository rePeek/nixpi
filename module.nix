# Pi coding agent — a simple nix-wrapper-modules wrapper.
#
# The generated JSON files live in the Nix store. At runtime they are linked
# into PI_CODING_AGENT_DIR, which remains writable for pi's sessions and auth.
{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  jsonType = wlib.types.structuredValueWith { typeName = "JSON"; };

  # Fixed plugin/theme declarations. Add or remove a plugin here explicitly.
  plugins = {
    hashline = import ./pi-hashline.nix;
    fff = import ./pi-fff.nix;
    webAccess = import ./pi-web-access.nix;
    codexSearch = import ./pi-codex-search.nix;
    toolDisplay = import ./pi-tool-display.nix;
    theme = import ./theme.nix;
  };

  # The theme has package = null, so it is excluded automatically.
  packages = map (plugin: plugin.package) (
    builtins.filter (plugin: plugin.package or null != null) (builtins.attrValues plugins)
  );

  settings = config.settings // {
    inherit packages;
    theme = plugins.theme.themeName;
  };

  # A mutable file is copied from the store once; an immutable file is always
  # replaced with a store symlink. `key` matches an entry in constructFiles.
  installConfig = key: relativePath:
    if config.mutableConfig then
      ''
        mkdir -p "$PI_CODING_AGENT_DIR/$(dirname "${relativePath}")"
        # Switching from immutable to mutable: replace the old store symlink.
        if [ -L "$PI_CODING_AGENT_DIR/${relativePath}" ]; then
          rm "$PI_CODING_AGENT_DIR/${relativePath}"
        fi
        # Keep later user edits; copy the Nix default only when it is absent.
        if [ ! -e "$PI_CODING_AGENT_DIR/${relativePath}" ]; then
          cp "${config.constructFiles.${key}.path}" "$PI_CODING_AGENT_DIR/${relativePath}"
          chmod u+w "$PI_CODING_AGENT_DIR/${relativePath}"
        fi
      ''
    else
      ''
        mkdir -p "$PI_CODING_AGENT_DIR/$(dirname "${relativePath}")"
        rm -f "$PI_CODING_AGENT_DIR/${relativePath}"
        ln -s "${config.constructFiles.${key}.path}" "$PI_CODING_AGENT_DIR/${relativePath}"
      '';
in
{
  imports = [ wlib.modules.default ];

  # Only core settings are an option. Override them through `.wrap { settings = ...; }`.
  options.settings = lib.mkOption {
    type = jsonType;
    default = import ./settings.nix;
    description = "Core pi settings, such as provider, model, and thinking level.";
  };

  options.agentDirDefault = lib.mkOption {
    type = lib.types.str;
    default = "$HOME/.pi/agent";
    example = "$HOME/.pi/agent-dev";
    description = ''
      Default writable pi agent directory. PI_CODING_AGENT_DIR takes precedence
      when it is already set in the environment.
    '';
  };

  options.mutableConfig = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Copy all generated JSON configuration files into the writable agent directory
      on first use. Later manual edits persist. When disabled, files are read-only
      symlinks to their Nix store versions.
    '';
  };

  config = {
    package = lib.mkDefault pkgs.pi-coding-agent;
    unsetVar = lib.mkDefault [ "DEV" ];
    runtimePkgs = [ pkgs.coreutils ];

    envDefault = lib.mkDefault {
      PI_SKIP_VERSION_CHECK = "1";
      PI_OFFLINE = "1";
      PI_FFF_MODE = plugins.fff.env.PI_FFF_MODE;
    };

    # Files embedded in the wrapped pi package under share/pi-config/.
    constructFiles = {
      settings = {
        content = builtins.toJSON settings;
        relPath = "share/pi-config/settings.json";
      };
      hashline = {
        content = builtins.toJSON plugins.hashline.config;
        relPath = "share/pi-config/hashline.json";
      };
      webSearch = {
        content = builtins.toJSON plugins.webAccess.config;
        relPath = "share/pi-config/web-search.json";
      };
      codexSearch = {
        content = builtins.toJSON plugins.codexSearch.config;
        relPath = "share/pi-config/pi-codex-search.json";
      };
      toolDisplay = {
        content = builtins.toJSON plugins.toolDisplay.config;
        relPath = "share/pi-config/extensions/pi-tool-display/config.json";
      };
      dracula = {
        content = builtins.toJSON plugins.theme.config;
        relPath = "share/pi-config/themes/dracula.json";
      };
    };

    # Pi needs a writable directory. Files are linked or copied once according
    # to mutableConfig.
    runShell = [
      ''
        export PI_CODING_AGENT_DIR="''${PI_CODING_AGENT_DIR:-${config.agentDirDefault}}"
        mkdir -p "$PI_CODING_AGENT_DIR"
        ${installConfig "settings" "settings.json"}
        ${installConfig "hashline" "hashline.json"}
        ${installConfig "webSearch" "web-search.json"}
        ${installConfig "codexSearch" "pi-codex-search.json"}
        ${installConfig "toolDisplay" "extensions/pi-tool-display/config.json"}
        ${installConfig "dracula" "themes/dracula.json"}
      ''
    ];
  };
}
