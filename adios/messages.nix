{ printList }:

let
  inherit (builtins)
    attrNames
    filter
    head
    length
    trace
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
  modulePathWarning = trace ''
    At least one of your Adios modules used `.path` to specify an input's location in the tree. This
    has been deprecated in favor of `.from`.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#promises-deprecations'' null;

  defaultFuncOnlyWarning = trace ''
    `defaultFunc` has been deprecated in favor of `default = promise ();`.
    See the lladios changelog for more info:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#promises-deprecations'' null;
  implOnlyWarning = trace ''
    `impl` has been deprecated in favor of `result = promise ();`.
    See the lladios changelog for more info:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#promises-deprecations'' null;
  mutationFunctionWarning = trace ''
    The function form of `mutations` has been deprecated.
    To let a mutation read from `args`, use `mutations."/foo".option = promise ()`.
    See the lladios changelog for more info:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#promises-deprecations'' null;

  defaultFuncAndDefaultWarning = trace ''
    Both `default` and `defaultFunc` were set.
    This is likely from a faulty injection, where the upstream module migrated to
    `default = promise ()`. You should do the same in your injection.
    Using the `defaultFunc` for now, as it's likely to be the one you actually
    meant.
    See the lladios changelog for more details:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#promises-deprecations'' null;
  implAndResultWarning = trace ''
    Both `result` and `impl` were set.
    This is likely from a faulty injection, where the upstream module migrated
    to `result = promise ()`. You should do the same in your injection.
    Using the `impl` for now, as it's likely to be the one you actually meant.
    See the lladios changelog for more details:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#promises-deprecations'' null;

  mutatorTypeWarning = trace ''
    At least one of your Adios modules used 'mutatorType' for an option. This has been deprecated, and 'type' now also
    applies to individual mutators as well. Options that use a different 'type' and 'mutatorType' should be refactored
    to use the same type.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#deprecated-mutatortype'' null;

  calledModuleWarning = trace ''
    Calling modules directly within an Adios tree has been deprecated.
    Instead, the options for an input should be specified inside `inputs.$name.options`. The result is then stored in `results.$name`.
    See the lladios changelog for more info:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#new-format-for-calling-options'' null;

  mergeFuncErrorMessage = ''
    option defined 'mergeFunc', but this is deprecated in favor of 'merge'.
    see the lladios changelog for more info:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#mergefunc-deprecated'';

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
