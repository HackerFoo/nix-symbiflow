let
  sf = import ../default.nix {};
in
{
  inherit (sf) symbiflow-arch-defs;
}
