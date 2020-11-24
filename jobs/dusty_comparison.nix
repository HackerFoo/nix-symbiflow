args@{ ... }:

with import ../default.nix args;
with builtins;
with pkgs;
with lib;
with callPackage ../default.nix {};

let
  fpga-tool-perf_baseline = make-fpga-tool-perf {
    extra_vpr_flags = {
      acc_fac = 1;
      astar_fac = 1.2;
      first_iter_pres_fac = 0;
      initial_pres_fac = 4;
      place_delay_model = "delta_override";
      pres_fac_mult = 1.3;
    };
  };
  fpga-tool-perf_dusty_perf = make-fpga-tool-perf {
    extra_vpr_flags = {
      acc_fac = 0.7;
      astar_fac = 1.8;
      first_iter_pres_fac = 0;
      initial_pres_fac = 2.828;
      place_delay_model = "delta";
      pres_fac_mult = 1.2;
    };
  };
  make_tests = fpga-tool-perf: suffix: concatMap (project:
    concatMap (toolchain:
      map (board: {
        name = "${project}_${toolchain}_${board}" + suffix;
        value = fpga-tool-perf.${project}.${toolchain}.${board};
      }) (attrNames fpga-tool-perf.${project}.${toolchain}))
      (attrNames fpga-tool-perf.${project}))
    (attrNames fpga-tool-perf);
in

listToAttrs (make_tests fpga-tool-perf_baseline "" ++ make_tests fpga-tool-perf_dusty_perf "_dusty_perf")
