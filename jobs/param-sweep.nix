args@{ ... }:

with import ../default.nix args;
with builtins;
with pkgs;
with lib;
with callPackage ../default.nix {};
with callPackage ../library.nix {};

let
  params_list = attr_sweep {
    place_delay_model = [ "delta" "delta_override" ];
    initial_pres_fac = [ 2 2.828 4 ]; # 2.828
    astar_fac = [ 1.2 1.5 1.6 1.8 2 ]; # 1.8
    first_iter_pres_fac = [ 0.5 ];
    pres_fac_mult = [ 1.1 1.15 1.2 1.25 1.3 ]; # 1.2
    acc_fac = [ 0.4 0.5 0.7 ]; # 0.7
  };
in

listToAttrs ((map (params: {
  name = "baselitex" + replaceStrings ["."] ["_"] (attrs_to_string "_" "_" params);
  value = (make-fpga-tool-perf { extra_vpr_flags = params; }).baselitex.vpr.arty;
}) params_list) ++
(map (params: {
  name = "ibex" + replaceStrings ["."] ["_"] (attrs_to_string "_" "_" params);
  value = (make-fpga-tool-perf { extra_vpr_flags = params; }).ibex.vpr.arty;
}) params_list) ++
(map (params: {
  name = "bram-n3" + replaceStrings ["."] ["_"] (attrs_to_string "_" "_" params);
  value = (make-fpga-tool-perf { extra_vpr_flags = params; }).bram-n3.vpr.arty;
}) params_list))
