{ toPretty }:
let
  inherit (builtins)
    zipAttrsWith
    head
    all
    isAttrs
    length
    ;
  isDerivation = value: (value.type or null) == "derivation";

in
{ mutators }:
let
  recurse = zipAttrsWith (
    key: values:
    if length values == 1 then
      head values
    else if all (value: isAttrs value && !isDerivation value) values then
      recurse values
    else
      throw ''
        while calling 'adios.merge.attrs.recursively':
        while attempting to merge mutators ${toPretty { recursivelyMultiline = false; } mutators}
        found key '${key}' set to multiple values that couldn't be merged
        unmergeable values: ${toPretty { multiline = false; } values}''
  );
in
recurse mutators
