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
    acc_fac = [ 0.5 0.7 1 ]; # 0.7
    astar_fac = [ 1.2 1.5 1.8 2 ]; # 1.8
    first_iter_pres_fac = [ 0 0.5 ];
    initial_pres_fac = [ 0.5 2 2.828 4 ]; # 2.828
    place_delay_model = [ "delta" "delta_override" ];
    pres_fac_mult = [ 1.1 1.2 1.3 ]; # 1.2
  };

  # Projects to run with each combination of parameters in params_list
  projects = [
    { name = "baselitex";             board = "arty-a35t"; }
    { name = "baselitex";             board = "arty-a100t"; }
    { name = "baselitex-nexys-video"; board = "nexys-video"; }
    { name = "ibex";                  board = "arty-a35t"; }
    { name = "ibex";                  board = "nexys-video"; }
    { name = "bram-n3";               board = "basys3"; }
    { name = "bram-n3";               board = "nexys-video"; }
  ];
in

# Create a job for each project and combination of parameters.
listToAttrs (concatMap (project:
  map (params: {
    name = project.name + "-" + project.board + replaceStrings ["."] ["_"] (attrs_to_string "_" "_" params);
    value = (make-fpga-tool-perf { extra_vpr_flags = params; }).${project.name}.vpr.${project.board};
  }) params_list) projects)
