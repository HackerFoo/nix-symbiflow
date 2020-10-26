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
    bb_factor = [ 6 8 10 ];
    initial_pres_fac = [ 1 2 3 4 8 ];
    astar_fac = [ 1.2 1.5 2 3 ];
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
