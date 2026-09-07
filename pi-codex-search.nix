# pi-codex-search plugin: explicit Codex subscription web search tool.
{
  name = "pi-codex-search.json";
  config = {
    enabled = true;
    standaloneEnabled = false;
    baseUrl = "https://chatgpt.com/backend-api";
    searchContextSize = "medium";
    freshness = "live";
    batchSize = 5;
  };
  package = "npm:pi-codex-search@0.1.5";
}
