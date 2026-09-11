{ pkgs }:
{
  config = [ "hashline.json" ];
  env = { };
  runtimePkgs = [ pkgs.ripgrep ];
}
