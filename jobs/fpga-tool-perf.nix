args@{ ... }:

with import ../default.nix args;
with builtins;
with pkgs;
with lib;
with callPackage ../default.nix {};

let
  make-fpga-tool-perf-slow = attrs: make-fpga-tool-perf ({
    extra_vpr_flags = {
      place_delay_model = "delta_override";
      acc_fac = 1;
      astar_fac = 1.2;
      initial_pres_fac = 4.0;
      pres_fac_mult = 1.3;
    };
  } // attrs);
  make_tests = jobs: suffix: concatMap (project:
    concatMap (toolchain:
      map (board: {
        name = "${project}_${toolchain}_${board}" + suffix;
        value = jobs.${project}.${toolchain}.${board};
      }) (attrNames jobs.${project}.${toolchain}))
      (attrNames jobs.${project}))
    (attrNames jobs);
in

listToAttrs (concatMap (iteration:
  make_tests
    (make-fpga-tool-perf-slow { inherit iteration; })
    ("-" + (toString iteration)))
  (range 0 7))
