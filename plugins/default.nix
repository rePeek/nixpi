{ pkgs }:
map (plugin: import plugin { inherit pkgs; }) [
  ./pi-codex-search.nix
  ./pi-fff.nix
  ./pi-hashline-edit.nix
  ./pi-tool-display.nix
  ./pi-web-access.nix
]
