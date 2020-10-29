args@{ ... }:

with import ../default.nix args;
with builtins;
with pkgs;
with lib;
with callPackage ../default.nix {};

let
  fpga-tool-perf_dusty_sa = make-fpga-tool-perf {
    extra_vpr_flags = {
      alpha_min = 0.4;
      alpha_max = 0.9;
      alpha_decay = 0.5;
      anneal_success_target = 0.6;
      anneal_success_min = 0.18;
    };
  };
  fpga-tool-perf_dusty_perf = make-fpga-tool-perf {
    extra_vpr_flags = {
      place_delay_model = "delta";
      initial_pres_fac = 2.828;
      astar_fac = 1.8;
      first_iter_pres_fac = 0.5;
      pres_fac_mult = 1.2;
      acc_fac = 0.7;
    };
  };
  fpga-tool-perf_reorder = make-fpga-tool-perf {
    extra_vpr_flags = {
      reorder_rr_graph_nodes_algorithm = "degree_bfs";
    };
  };
  baseline_tests = concatMap (project:
    concatMap (toolchain:
      map (board: {
        name = "${project}_${toolchain}_${board}";
        value = fpga-tool-perf.${project}.${toolchain}.${board};
      }) (attrNames fpga-tool-perf.${project}.${toolchain}))
      (attrNames fpga-tool-perf.${project}))
    (attrNames fpga-tool-perf);
  dusty_sa_tests = concatMap (project:
    concatMap (toolchain:
      optionals (hasPrefix "vpr" toolchain)
        (map (board: {
          name = "${project}_${toolchain}_${board}_dusty_sa";
          value = fpga-tool-perf_dusty_sa.${project}.${toolchain}.${board};
        }) (attrNames fpga-tool-perf_dusty_sa.${project}.${toolchain})))
      (attrNames fpga-tool-perf_dusty_sa.${project}))
    (attrNames fpga-tool-perf_dusty_sa);
  dusty_perf_tests = concatMap (project:
    concatMap (toolchain:
      optionals (hasPrefix "vpr" toolchain)
        (map (board: {
          name = "${project}_${toolchain}_${board}_dusty_perf";
          value = fpga-tool-perf_dusty_perf.${project}.${toolchain}.${board};
        }) (attrNames fpga-tool-perf_dusty_perf.${project}.${toolchain})))
      (attrNames fpga-tool-perf_dusty_perf.${project}))
    (attrNames fpga-tool-perf_dusty_perf);
  reorder_tests = concatMap (project:
    concatMap (toolchain:
      optionals (hasPrefix "vpr" toolchain)
        (map (board: {
          name = "${project}_${toolchain}_${board}_reorder";
          value = fpga-tool-perf_reorder.${project}.${toolchain}.${board};
        }) (attrNames fpga-tool-perf_reorder.${project}.${toolchain})))
      (attrNames fpga-tool-perf_reorder.${project}))
    (attrNames fpga-tool-perf_reorder);
in

listToAttrs (baseline_tests ++ dusty_sa_tests ++ dusty_perf_tests ++ reorder_tests)
