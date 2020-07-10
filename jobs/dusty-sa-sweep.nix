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
        alpha_min = [0.75 0.8 0.82];
        alpha_max = [0.88 0.9 0.92];
        alpha_decay = [0.42 0.4 0.38];
        anneal_success_target = [0.58 0.6 0.62];
        anneal_success_min = [0.17 0.18 0.19 0.2];
      });
in

listToAttrs (map (params: {
  name = "baselitex" + replaceStrings ["."] ["_"] (attrs_to_string "_" "_" params);
  value = (make-fpga-tool-perf params).baselitex.vpr.arty.value;
}) params_list)
