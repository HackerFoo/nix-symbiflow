{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

with builtins;
with pkgs;
with lib;
with callPackage ../default.nix { use-vivado = true; };
with callPackage ../library.nix {};

let
  params_list =
    filter
      (x: (x.alpha_min < x.alpha_max) && (x.anneal_success_min < x.anneal_success_target))
      (attr_sweep {
        alpha_min = [0.79 0.8 0.81];
        alpha_max = [0.89 0.9 0.91];
        alpha_decay = [0.41 0.4 0.39];
        anneal_success_target = [0.59 0.6 0.61];
        anneal_success_min = [0.178 0.18 0.182];
      });
in

listToAttrs (map (params: {
  name = "baselitex" + replaceStrings ["."] ["_"] (attrs_to_string "_" "_" params);
  value = (make-fpga-tool-perf params).baselitex.vpr.arty.value;
}) params_list)
