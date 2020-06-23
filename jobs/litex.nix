{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

(import ../default.nix { inherit pkgs; use-vivado = true; }).litex-buildenv
