{
  description = "Standalone Pi coding agent with baked-in configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Build the agent directory in the nix store
      agentDir = pkgs.linkFarm "pi-agent" [
        {
          name = "settings.json";
          path = pkgs.writeText "settings.json" (builtins.toJSON {
            defaultProvider = "csi-provider";
            defaultModel = "Qwen3.7-Max";
            defaultThinkingLevel = "high";
            enableInstallTelemetry = false;
            hideThinkingBlock = true;
            showCacheMissNotices = true;
            packages = [
              "npm:pi-tool-display@0.5.0"
              "npm:pi-codex-search@0.1.5"
              "npm:pi-web-access@0.13.0"
              "npm:@ff-labs/pi-fff@0.10.1"
              "npm:pi-hashline-edit@0.8.3"
            ];
            theme = "dracula";
          });
        }
        {
          name = "hashline.json";
          path = pkgs.writeText "hashline.json" (builtins.toJSON {
            hashLength = 3;
            grep = false;
            replaceText = false;
          });
        }
        {
          name = "pi-codex-search.json";
          path = pkgs.writeText "pi-codex-search.json" (builtins.toJSON {
            enabled = true;
            standaloneEnabled = false;
            baseUrl = "https://chatgpt.com/backend-api";
            searchContextSize = "medium";
            freshness = "live";
            batchSize = 5;
          });
        }
        {
          name = "web-search.json";
          path = pkgs.writeText "web-search.json" (builtins.toJSON {
            provider = "openai";
            workflow = "none";
            allowBrowserCookies = false;
            webSearch.enabled = false;
            githubClone = {
              enabled = true;
              maxRepoSizeMB = 350;
              cloneTimeoutSeconds = 30;
              clonePath = "/tmp/pi-github-repos";
            };
            youtube.enabled = false;
            video.enabled = false;
          });
        }
        {
          name = "themes/dracula.json";
          path = pkgs.writeText "dracula.json" (builtins.toJSON {
            name = "dracula";
            vars = {
              background = "#282a36";
              currentLine = "#44475a";
              foreground = "#f8f8f2";
              comment = "#6272a4";
              cyan = "#8be9fd";
              green = "#50fa7b";
              orange = "#ffb86c";
              pink = "#ff79c6";
              purple = "#bd93f9";
              red = "#ff5555";
              yellow = "#f1fa8c";
              bgLight = "#343746";
              bgLighter = "#3c3f58";
              bgDark = "#21222c";
              bgGreenTint = "#2a3a2e";
              bgRedTint = "#3a2a2e";
              bgPurpleTint = "#2e2a3a";
            };
            colors = {
              accent = "purple";
              border = "purple";
              borderAccent = "pink";
              borderMuted = "comment";
              success = "green";
              error = "red";
              warning = "yellow";
              muted = "comment";
              dim = "#545978";
              text = "foreground";
              thinkingText = "comment";
              selectedBg = "currentLine";
              userMessageBg = "bgLight";
              userMessageText = "foreground";
              customMessageBg = "bgPurpleTint";
              customMessageText = "foreground";
              customMessageLabel = "purple";
              toolPendingBg = "bgDark";
              toolSuccessBg = "bgGreenTint";
              toolErrorBg = "bgRedTint";
              toolTitle = "foreground";
              toolOutput = "comment";
              mdHeading = "orange";
              mdLink = "cyan";
              mdLinkUrl = "comment";
              mdCode = "green";
              mdCodeBlock = "foreground";
              mdCodeBlockBorder = "comment";
              mdQuote = "comment";
              mdQuoteBorder = "comment";
              mdHr = "comment";
              mdListBullet = "pink";
              toolDiffAdded = "green";
              toolDiffRemoved = "red";
              toolDiffContext = "comment";
              syntaxComment = "comment";
              syntaxKeyword = "pink";
              syntaxFunction = "green";
              syntaxVariable = "foreground";
              syntaxString = "yellow";
              syntaxNumber = "purple";
              syntaxType = "cyan";
              syntaxOperator = "pink";
              syntaxPunctuation = "foreground";
              thinkingOff = "#545978";
              thinkingMinimal = "comment";
              thinkingLow = "cyan";
              thinkingMedium = "purple";
              thinkingHigh = "pink";
              thinkingXhigh = "red";
              bashMode = "green";
            };
            export = {
              pageBg = "#1e1f29";
              cardBg = "bgDark";
              infoBg = "#3a3728";
            };
          });
        }
        {
          name = "extensions/pi-tool-display/config.json";
          path = pkgs.writeText "pi-tool-display-config.json" (builtins.toJSON {
            debug = false;
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
          });
        }
      ];

      # Wrap pi with the baked-in config
      pi-with-config = pkgs.symlinkJoin {
        name = "pi-with-config";
        paths = [ pkgs.pi-coding-agent ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/pi \
            --set PI_CODING_AGENT_DIR "${agentDir}" \
            --set PI_SKIP_VERSION_CHECK "1" \
            --set PI_OFFLINE "1" \
            --set PI_FFF_MODE "override"
        '';
        meta = {
          mainProgram = "pi";
          description = "Pi coding agent with baked-in configuration";
        };
      };

    in
    {
      packages.${system} = {
        default = pi-with-config;
        pi = pi-with-config;
      };

      apps.${system}.default = {
        type = "app";
        program = "${pi-with-config}/bin/pi";
      };

      # Also export for Home Manager integration
      homeManagerModules.default = { pkgs, ... }: {
        home.packages = [ pi-with-config ];
      };
    };
}
