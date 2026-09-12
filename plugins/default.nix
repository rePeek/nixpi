{ pkgs }:
map (plugin: import plugin { inherit pkgs; }) [
  ./pi-cc-extensions.nix
  ./pi-fff.nix
  ./pi-hashline-edit.nix
  ./pi-web-access.nix
]
