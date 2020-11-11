{
  pkgs ? import <nixpkgs> {}
}:

let
  
  callPackage = pkgs.lib.callPackageWith (pkgs // pkgs.xlibs // pkgs.python3Packages // self);
  
  self = {
    vivado = callPackage ./pkgs/vivado { };
    vivado-latest = callPackage ./pkgs/vivado-latest { };
    migen = callPackage ./pkgs/migen { };
  };
in
self
