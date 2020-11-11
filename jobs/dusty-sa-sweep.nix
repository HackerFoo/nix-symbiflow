args@{ ... }:

with import ../default.nix args;
with builtins;
with pkgs;
with lib;
with callPackage ../default.nix {};
with callPackage ../library.nix {};

let
  params_list =
    filter
      (x: (x.alpha_min < x.alpha_max) && (x.anneal_success_min < x.anneal_success_target))
      (attr_sweep {
        alpha_min = [0.2 0.3 0.4 0.6 0.8];
        alpha_max = [0.8 0.9 0.95 0.98];
        alpha_decay = [0.2 0.3 0.4 0.5];
        anneal_success_target = [0.15 0.44 0.6 0.7];
        anneal_success_min = [0.08 0.1 0.18];
      });
in

listToAttrs ((map (params: {
  name = "baselitex" + replaceStrings ["."] ["_"] (attrs_to_string "_" "_" params);
  value = (make-fpga-tool-perf { extra_vpr_flags = params; }).baselitex.vpr.arty;
}) params_list) ++
(map (params: {
  name = "ibex" + replaceStrings ["."] ["_"] (attrs_to_string "_" "_" params);
  value = (make-fpga-tool-perf { extra_vpr_flags = params; }).ibex.vpr.arty;
}) params_list))
