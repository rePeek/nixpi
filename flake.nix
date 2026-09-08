{
  description = "Pi coding agent — declarative configuration as code";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      mkPi = import ./lib.nix { inherit pkgs; };
    in
    {
      # Expose mkPi so consumers can build a customized pi with their own modules.
      lib.mkPi = { modules ? [ ] }: mkPi { inherit modules; };

      # Default build: all modules enabled.
      packages.${system}.default = mkPi { };

      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/pi";
      };

      # Home Manager integration: install the default pi build.
      homeManagerModules.default = _: {
        home.packages = [ (mkPi { }) ];
      };
    };
}
