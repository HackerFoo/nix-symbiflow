args@{ ... }:

{
  inherit (import ../default.nix args)
    symbiflow-arch-defs
    symbiflow-arch-defs-200t;
}
