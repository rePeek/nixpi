{
  description = "Pi coding agent Home Manager module";

  outputs = _: {
    homeManagerModules.default = import ./default.nix;
  };
}
