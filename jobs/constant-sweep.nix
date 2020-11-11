args@{ ... }:

with import ../default.nix args;
with builtins;
with pkgs;
with lib;
with callPackage ../default.nix {};
with callPackage ../library.nix {};

let
  params_list = attr_sweep {
    kIncreaseFocusLimit = [ 2011 2017 2027 2029 2039 2048 2053 2063 2069 2081 2083 ];
    kScale = [ 1.4 1.7 2 2.2 2.5 3 5 ]; # 2, 3
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
