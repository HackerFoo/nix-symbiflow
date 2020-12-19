args@{ ... }:

with import ../default.nix args;
with builtins;
with pkgs;
with lib;
with callPackage ../default.nix {};

let
  make_tests = jobs: suffix: concatMap (project:
    concatMap (toolchain:
      map (board: {
        name = "${project}_${toolchain}_${board}" + suffix;
        value = jobs.${project}.${toolchain}.${board};
      }) (attrNames jobs.${project}.${toolchain}))
      (attrNames jobs.${project}))
    (attrNames jobs);
  jobs = make-fpga-tool-perf {
    extra_vpr_flags = {
      acc_fac = 1.0;
      astar_fac = 2.0;
      first_iter_pres_fac = 0;
      initial_pres_fac = 2.828;
      place_delay_model = "delta_override";
      pres_fac_mult = 1.2;
    };
  };
in

listToAttrs (make_tests jobs "")
