# pi-web-access plugin: web search, GitHub cloning and media extraction.
{
  config = {
    provider = "openai";
    workflow = "none";
    allowBrowserCookies = false;

    webSearch = {
      # Use pi-codex-search for an explicit, non-fallback Codex search tool.
      enabled = false;
    };

    githubClone = {
      enabled = true;
      maxRepoSizeMB = 350;
      cloneTimeoutSeconds = 30;
      clonePath = "/tmp/pi-github-repos";
    };

    youtube = {
      enabled = false;
    };

    video = {
      enabled = false;
    };
  };
  package = "npm:pi-web-access@0.13.0";
}
