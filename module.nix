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
      ''
    ];
  };
}
