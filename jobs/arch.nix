{ pkgs ? import <nixpkgs> {} }:

let
  sf = import ../default.nix { inherit pkgs; };
in
{
  inherit (sf) symbiflow-arch-defs;
}
