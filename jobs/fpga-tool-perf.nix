{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

with builtins;
with pkgs;
with lib;
with import ../default.nix { inherit pkgs; use-vivado = true; };

let
  baseline_tests = concatMap (project:
    concatMap (toolchain:
      map (board: {
        name = "${project}_${toolchain}_${board}";
        value = fpga-tool-perf.${project}.${toolchain}.${board}.value; # strange that I need to add .value
      }) (attrNames fpga-tool-perf.${project}.${toolchain}))
      (attrNames fpga-tool-perf.${project}))
    (attrNames fpga-tool-perf);
  dusty_sa_tests = concatMap (project:
    concatMap (toolchain:
      optionals (hasPrefix "vpr" toolchain)
        (map (board: {
          name = "${project}_${toolchain}_${board}_dusty_sa";
          value = fpga-tool-perf_dusty_sa.${project}.${toolchain}.${board}.value; # strange that I need to add .value
        }) (attrNames fpga-tool-perf_dusty_sa.${project}.${toolchain})))
      (attrNames fpga-tool-perf_dusty_sa.${project}))
    (attrNames fpga-tool-perf_dusty_sa);
in

listToAttrs (baseline_tests ++ dusty_sa_tests)
