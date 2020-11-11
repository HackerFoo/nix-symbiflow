args@{ ... }:

with import ../default.nix args;
with builtins;
with pkgs;
with lib;
with callPackage ../default.nix {};
with callPackage ../library.nix {};

let
  # Parameter combinations to try
  params_list = attr_sweep {
    place_delay_model = [ "delta" "delta_override" ];
    initial_pres_fac = [ 0.5 2 2.828 4 ]; # 2.828
    astar_fac = [ 1.2 1.5 1.8 2 ]; # 1.8
    first_iter_pres_fac = [ 0 0.5 ];
    pres_fac_mult = [ 1.1 1.2 1.3 ]; # 1.2
    acc_fac = [ 0.5 0.7 1 ]; # 0.7
  };

  # Projects to run with each combination of parameters in params_list
  projects = [
    { name = "baselitex"; board = "arty"; }
    { name = "ibex";      board = "arty"; }
    { name = "bram-n3";   board = "basys3"; }
  ];
in

# Create a job for each project and combination of parameters.
listToAttrs (concatMap (project:
  map (params: {
    name = project.name + replaceStrings ["."] ["_"] (attrs_to_string "_" "_" params);
    value = (make-fpga-tool-perf { extra_vpr_flags = params; }).${project.name}.vpr.${project.board};
  }) params_list) projects)
