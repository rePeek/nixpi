{
  description = "Standalone Pi coding agent with baked-in configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      agentDir = import ./config.nix { inherit pkgs; };

      # Collect env vars from modules that declare them.
      modules = [
        (import ./pi-fff.nix)
      ];
      extraEnv = builtins.concatStringsSep "\n" (
        map
          (m:
            builtins.concatStringsSep "\n" (
              map (k: "          export ${k}=\"${m.env.${k}}\"") (builtins.attrNames m.env)
            )
          )
          (builtins.filter (m: m ? env && m.env != null) modules)
      );

      pi-with-config = pkgs.writeShellApplication {
        name = "pi";
        runtimeInputs = [ pkgs.pi-coding-agent pkgs.coreutils ];
        text = ''
          export PI_CODING_AGENT_DIR="''${PI_CODING_AGENT_DIR:-"$HOME/.pi/agent"}"
          export PI_SKIP_VERSION_CHECK=1
          export PI_OFFLINE=1
          ${extraEnv}

          # Ensure agent directory exists and is populated from the nix store.
          mkdir -p "$PI_CODING_AGENT_DIR/themes" "$PI_CODING_AGENT_DIR/extensions/pi-tool-display"

          for f in settings.json hashline.json pi-codex-search.json web-search.json; do
            [ -f "$PI_CODING_AGENT_DIR/$f" ] || cp "${agentDir}/$f" "$PI_CODING_AGENT_DIR/$f"
          done
          [ -f "$PI_CODING_AGENT_DIR/themes/dracula.json" ] || \
            cp "${agentDir}/themes/dracula.json" "$PI_CODING_AGENT_DIR/themes/dracula.json"
          [ -f "$PI_CODING_AGENT_DIR/extensions/pi-tool-display/config.json" ] || \
            cp "${agentDir}/extensions/pi-tool-display/config.json" \
              "$PI_CODING_AGENT_DIR/extensions/pi-tool-display/config.json"

          exec pi "$@"
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

      # Also export for Home Manager integration.
      homeManagerModules.default = { pkgs, ... }: {
        home.packages = [ pi-with-config ];
      };
    };
}
