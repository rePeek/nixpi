# Pi coding agent Home Manager entry point.
# Aggregates core settings, theme and per-plugin modules.
{
  config,
  ...
}:
{
  imports = [
    ./theme.nix
    ./pi-hashline.nix
    ./pi-fff.nix
    ./pi-web-access.nix
    ./pi-codex-search.nix
    ./pi-tool-display.nix
  ];

  programs.pi-coding-agent = {
    enable = true;

    settings = {
      defaultProvider = "csi-provider";
      defaultModel = "Qwen3.7-Max";
      defaultThinkingLevel = "high";

      enableInstallTelemetry = false;
      hideThinkingBlock = true;

      # 做缓存实验时保留
      showCacheMissNotices = true;
    };
  };

  home.sessionVariables = {
    PI_SKIP_VERSION_CHECK = "1";
    PI_CODING_AGENT_DIR = "${config.home.homeDirectory}/.pi/agent";
    PI_OFFLINE = "1";
  };
}
