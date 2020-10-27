args@{ ... }:

with import ../default.nix args;
with builtins;
with pkgs;
with lib;
with callPackage ../default.nix {};
with callPackage ../library.nix {};

let
  params_list = attr_sweep {
    kIncreaseFocusLimit = [ 31 64 256 2039 2048 16000 ]; # 256
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
