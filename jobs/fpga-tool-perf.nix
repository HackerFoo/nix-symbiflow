{ pkgs ? import <nixpkgs> {} }:

with builtins;
with pkgs;
with lib;
with import ../default.nix { inherit pkgs; };

listToAttrs (concatMap (project:
  concatMap (toolchain:
    map (board: {
      name = "${project}_${toolchain}_${board}";
      value = fpga-tool-perf.${project}.${toolchain}.${board}.value; # strange that I need to add .value
    }) (attrNames fpga-tool-perf.${project}.${toolchain}))
    (attrNames fpga-tool-perf.${project}))
  (attrNames fpga-tool-perf))
