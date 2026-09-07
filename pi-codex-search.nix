# pi-codex-search plugin: explicit Codex subscription web search tool.
_: {
  programs.pi-coding-agent.settings.packages = [
    "npm:pi-codex-search@0.1.5"
  ];

  home.file.".pi/agent/pi-codex-search.json".text = builtins.toJSON {
    enabled = true;
    standaloneEnabled = false;
    baseUrl = "https://chatgpt.com/backend-api";
    searchContextSize = "medium";
    freshness = "live";
    batchSize = 5;
  };
}
