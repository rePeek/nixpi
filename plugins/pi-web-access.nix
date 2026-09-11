{ pkgs }:
{
  config = [ "web-search.json" ];
  env = { };
  runtimePkgs = [ pkgs.git ];
}
