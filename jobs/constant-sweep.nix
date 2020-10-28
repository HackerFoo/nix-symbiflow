args@{ ... }:

with import ../default.nix args;
with builtins;
with pkgs;
with lib;
with callPackage ../default.nix {};
with callPackage ../library.nix {};

let
  params_list = attr_sweep {
    kIncreaseFocusLimit = [ 7 17 31 61 127 253 256 511 512 1021 1543 2039 2048 ];
    kScale = [ 2 3 5 ]; # 3
  };
in

listToAttrs ((map (params: {
  name = "baselitex" + replaceStrings ["."] ["_"] (attrs_to_string "_" "_" params);
  value = (make-fpga-tool-perf { constants = { "vpr/src/route/bucket.cpp" = params; }; }).baselitex.vpr.arty;
}) params_list) ++
(map (params: {
  name = "ibex" + replaceStrings ["."] ["_"] (attrs_to_string "_" "_" params);
  value = (make-fpga-tool-perf { constants = { "vpr/src/route/bucket.cpp" = params; }; }).ibex.vpr.arty;
}) params_list))
