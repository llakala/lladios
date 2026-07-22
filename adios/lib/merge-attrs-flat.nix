{ toPretty }:
let
  inherit (builtins)
    filter
    head
    length
    zipAttrsWith
    ;

in
{ mutators }:
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
      Collision on key '${name}' between mutators '${
        toPretty { recursivelyMultiline = false; } badMutators
      }'.
    ''
) mutators
