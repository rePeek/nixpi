# pi-tool-display plugin: compact tool-call rendering and diff visualization.
_: {
  programs.pi-coding-agent.settings.packages = [
    "npm:pi-tool-display@0.5.0"
  ];

  home.file.".pi/agent/extensions/pi-tool-display/config.json".text = builtins.toJSON {
    debug = false;

    # 避免与 pi-fff (grep/find/ls) 和 pi-hashline-edit (read/edit) 冲突。
    registerToolOverrides = {
      read = false;
      grep = false;
      find = false;
      ls = false;
      bash = true;
      edit = false;
      write = true;
    };

    customToolOverrides = { };

    enableNativeUserMessageBox = true;

    readOutputMode = "hidden";
    searchOutputMode = "hidden";
    mcpOutputMode = "hidden";

    previewLines = 8;
    expandedPreviewMaxLines = 4000;

    bashOutputMode = "opencode";
    bashCollapsedLines = 10;

    diffViewMode = "auto";
    diffIndicatorMode = "bars";
    diffSplitMinWidth = 120;
    diffCollapsedLines = 24;
    diffWordWrap = true;

    showTruncationHints = false;
    showRtkCompactionHints = false;
  };
}
