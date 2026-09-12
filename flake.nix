{
  description = "Pi coding agent — Nix runtime wrapper";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.wrappers.url = "github:nix-community/nix-wrapper-modules";
  inputs.wrappers.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    {
      self,
      nixpkgs,
      wrappers,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      module = ./module.nix;
      wrapper = wrappers.lib.evalModule module;
      devOptions = {
        agentDirDefault = "$HOME/.pi/agent-dev";
        configDir = "$PWD/config";
        configMode = "mutable";
      };
    in
    {
      # Overlay: replace pi with the wrapped version.
      overlays.default = final: prev: {
        pi = wrapper.config.wrap { pkgs = prev; };
      };

      # Packages: the wrapped pi derivation for each system.
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = wrapper.config.wrap { inherit pkgs; };
          pi-dev = wrapper.config.wrap (devOptions // { inherit pkgs; });
        }
      );

      # Apps run the wrapped packages directly.
      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/pi";
          meta.description = "Pi with Nix-provided runtime";
        };
        pi-dev = {
          type = "app";
          program = "${self.packages.${system}.pi-dev}/bin/pi";
          meta.description = "Pi dev environment (separate agent dir)";
        };
      });
    };
}
