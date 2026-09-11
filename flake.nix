{
  description = "Pi coding agent — declarative wrapper using nix-wrapper-modules";

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
      forAllSystems = with nixpkgs.lib; genAttrs platforms.all;
      module = ./module.nix;
      wrapper = wrappers.lib.evalModule module;
      devOptions = {
        agentDirDefault = "$HOME/.pi/agent-dev";
        configDir = "$PWD/config";
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

      # App: run the wrapped pi directly.
      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/pi";
        };
        pi-dev = {
          type = "app";
          program = "${self.packages.${system}.pi-dev}/bin/pi";
        };
      });
    };
}
