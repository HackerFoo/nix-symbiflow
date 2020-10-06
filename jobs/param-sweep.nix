args@{ ... }:

with import ../default.nix args;
with builtins;
with pkgs;
with lib;
with callPackage ../default.nix {};
with callPackage ../library.nix {};

let
  params_list = attr_sweep {
    router_heap = [ "bucket" "binary" ];
    place_delay_model = [ "delta" "delta_override" ];
    bb_factor = [ 8 10 ];
    initial_pres_fac = [ 0.5 1 2 4 8 ];
    congested_routing_iteration_threshold = [ 0.8 1 ];
    base_cost_type = [ "delay_normalized_length" "delay_normalized_length_bounded" ];
    astar_fac = [ 1.2 1.5 2 ];
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
