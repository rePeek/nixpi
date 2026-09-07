# pi-web-access plugin: web search, GitHub cloning and media extraction.
_: {
  programs.pi-coding-agent.settings.packages = [
    "npm:pi-web-access@0.13.0"
  ];

  home.file.".pi/agent/web-search.json".text = builtins.toJSON {
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
}
