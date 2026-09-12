{ pkgs }:
map (integration: import integration { inherit pkgs; }) [
  ./pi-cc-extensions.nix
  ./pi-fff.nix
  ./pi-hashline-edit.nix
  ./pi-web-access.nix
]
