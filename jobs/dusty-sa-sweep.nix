{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

with builtins;
with pkgs;
with lib;
with callPackage ../default.nix { use-vivado = true; };
with callPackage ../library.nix {};

let
  params_list =
    attr_sweep {
      alpha_min = [0.7 0.8 0.85];
      alpha_max = [0.86 0.9];
      alpha_decay = [0.55 0.5 0.45 0.4];
      anneal_success_target = [0.5 0.55 0.6 0.65];
      anneal_success_min = [0.1 0.15];
    };
in

listToAttrs (map (params: {
  name = "baselitex" + replaceStrings ["."] ["_"] (attrs_to_string "_" "_" params);
  value = (make-fpga-tool-perf params).baselitex.vpr.arty.value;
}) params_list)
