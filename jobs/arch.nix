{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  sf = import ../default.nix { inherit pkgs; };
in
{
  inherit (sf) symbiflow-arch-defs;
}
