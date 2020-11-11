{
  pkgs ? import <nixpkgs> {}
}:

with builtins;
with pkgs;
with lib;

rec {
  # attr_sweep :: attrs -> [attrs]
  attr_sweep = attrs:
    let
      # generate a copy for each attrset in the list with each value of the given attribute name
      expandAttrs = lst: name:
        let
          vals = getAttr name attrs;

          # generate an attrset for each of vals
          varyAttrs = a: map (x: a // { ${name} = x; }) vals;
        in
          concatMap varyAttrs lst;
    in
      foldl expandAttrs [{}] (attrNames attrs);

  toString = x:
    if isString x
    then x
    else
      assert isInt x || isFloat x;
      toJSON x;

  attrs_to_string = ks: vs: attrs:
    foldl (str: name: str + ks + name + vs + (toString (getAttr name attrs))) "" (attrNames attrs);

  flags_to_string = attrs_to_string " --" " ";

}
