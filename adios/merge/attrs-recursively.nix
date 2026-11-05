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
definitions:
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
        while attempting to merge definitions ${toPretty { recursivelyMultiline = false; } definitions}
        found key '${key}' set to multiple values that couldn't be merged
        unmergeable values: ${toPretty { multiline = false; } values}''
  );
in
recurse definitions
