{ toPretty }:
let
  inherit (builtins)
    filter
    head
    length
    zipAttrsWith
    ;

in
definitions:
zipAttrsWith (
  name: values:
  if length values == 1 then
    # Only one definition
    head values
  else
    let
      badDefinitions = filter (def: def ? ${name}) definitions;
    in
    throw ''
      while calling 'adios.merge.attrs.flat':
      while attempting to merge definitions '${
        toPretty { recursivelyMultiline = false; } badDefinitions
      }':
      found multiple definitions attempting to set key '${name}'
    ''
) definitions
