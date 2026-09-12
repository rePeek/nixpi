{ pkgs }:
map (integration: import integration { inherit pkgs; }) [
  ./pi-hashline-edit.nix
  ./pi-web-access.nix
]
