args@{ ... }:
{
  inherit (import ../default.nix args)
    litex-buildenv;
}
