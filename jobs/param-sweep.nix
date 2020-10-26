args@{ ... }:

with import ../default.nix args;
with builtins;
with pkgs;
with lib;
with callPackage ../default.nix {};
with callPackage ../library.nix {};

let
  params_list = attr_sweep {
    place_delay_model = [ "delta" ];
    bb_factor = [ 8 10 ];
    initial_pres_fac = [ 2 4 ];
    astar_fac = [ 1.2 1.5 2 ];
    first_iter_pres_fac = [ 0 0.25 0.5 1 ];
    pres_fac_mult = [ 1.1 1.3 1.5 2 ];
    acc_fac = [ 0.5 1 2 ];
  };
in

listToAttrs ((map (params: {
  name = "baselitex" + replaceStrings ["."] ["_"] (attrs_to_string "_" "_" params);
  value = (make-fpga-tool-perf params).baselitex.vpr.arty;
}) params_list) ++
(map (params: {
  name = "ibex" + replaceStrings ["."] ["_"] (attrs_to_string "_" "_" params);
  value = (make-fpga-tool-perf params).ibex.vpr.arty;
}) params_list))
