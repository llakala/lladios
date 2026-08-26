{ warn, printList }:

let
  inherit (builtins)
    attrNames
    filter
    head
    length
    ;

  typeOf =
    let
      inherit (builtins) typeOf;
    in
    v:
    let
      vType = typeOf v;
    in
    if vType == "lambda" then
      "function"
    else if vType == "set" then
      "attrs"
    else
      vType;
in
{
  modulePathWarning = warn ''
    at least one of your Adios modules used `.path` to specify an input's location in the tree. This
    has been deprecated in favor of `.from`.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#input-references
  '' null;

  mutatorTypeWarning = warn ''
    at least one of your adios modules used 'mutatorType' for an option. This has been deprecated, and 'type' now also
    applies to individual mutators as well. Options that use a different 'type' and 'mutatorType' should be refactored
    to use the same type.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#deprecated-mutatortype
  '' null;

  mkMissingParamsError =
    self: errorContext: options: params:
    let
      missingNames = filter (param: !options ? ${param}) (attrNames params);
    in
    throw "${errorContext} ${self.path}: tried to set nonexistent ${
      if length missingNames == 1 then
        "option '${head missingNames}'"
      else
        "options '${printList missingNames}'"
    }, valid options were '${printList (attrNames options)}'";

  mkBadDefError =
    path: def:
    let
      defType = typeOf def;
      baseMessage = "in module '${path}': module is of type '${defType}', but Adios modules should be attrsets.";
    in
    throw (
      if defType != "function" then
        baseMessage
      else
        ''
          ${baseMessage}
                 hint: since your module is a function, you probably expected it to be called with
                 'adios' automatically. To do this, use 'adios.lib.importModules' on a directory.''
    );
}
