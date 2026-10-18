{ toPretty }:
let
  inherit (builtins)
    filter
    head
    length
    zipAttrsWith
    ;

in
mutators:
zipAttrsWith (
  name: values:
  if length values == 1 then
    # Only one mutator
    head values
  else
    let
      badMutators = filter (mutator: mutator ? ${name}) mutators;
    in
    throw ''
      while calling 'adios.merge.attrs.flat':
      while attempting to merge mutators '${
        toPretty { recursivelyMultiline = false; } badMutators
      }':
      found multiple mutators attempting to set key '${name}'
    ''
) mutators
