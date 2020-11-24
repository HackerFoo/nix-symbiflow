args@{ ... }:

with import ../default.nix args;
with builtins;
with pkgs;
with lib;
with callPackage ../default.nix {};

let
  make_tests = fpga-tool-perf: suffix: concatMap (project:
    concatMap (toolchain:
      map (board: {
        name = "${project}_${toolchain}_${board}" + suffix;
        value = fpga-tool-perf.${project}.${toolchain}.${board};
      }) (attrNames fpga-tool-perf.${project}.${toolchain}))
      (attrNames fpga-tool-perf.${project}))
    (attrNames fpga-tool-perf);
in

listToAttrs (make_tests fpga-tool-perf "")
