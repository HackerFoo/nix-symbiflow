args@{ ... }:

with import ../default.nix args;
with builtins;
with pkgs;
with lib;
with callPackage ../default.nix {};
with callPackage ../library.nix {};

let
  params_list = attr_sweep {
    alpha_min = [0.8];
    alpha_max = [0.9];
    alpha_decay = [0.4];
    anneal_success_target = [0.6];
    anneal_success_min = [0.18];
    reorder_rr_graph_nodes_algorithm = ["degree_bfs"];
    router_high_fanout_max_slope = [0.1 0.25 0.5 0.7];
    router_high_fanout_threshold = [(-1) 16 32 64 96 128 192 256];
  };
in

listToAttrs (map (params: {
  name = "ibex" + replaceStrings ["."] ["_"] (attrs_to_string "_" "_" params);
  value = (make-fpga-tool-perf { extra_vpr_flags = params; }).ibex.vpr.arty.value;
}) params_list)
