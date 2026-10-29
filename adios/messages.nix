let
  inherit (builtins)
    attrNames
    concatStringsSep
    filter
    head
    length
    trace
    ;

  traceMessage = msg: trace msg null;
  printList = list: "[${concatStringsSep ", " list}]";

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
  modulePathWarning = traceMessage ''
    At least one of your Adios modules used `.path` to specify an input's location in the tree. This
    has been deprecated in favor of `.from`.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#promises-deprecations'';

  defaultFuncOnlyWarning = traceMessage ''
    `defaultFunc` has been deprecated in favor of `default = promise ();`.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#promises-deprecations'';

  implOnlyWarning = traceMessage ''
    `impl` has been deprecated in favor of `result = promise ();`.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#promises-deprecations'';

  mutationFunctionWarning = traceMessage ''
    The function form of `mutations` has been deprecated.
    To let a mutation read from `args`, use `mutations."/foo".option = promise ()`.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#promises-deprecations'';

  defaultFuncAndDefaultWarning = traceMessage ''
    Both `default` and `defaultFunc` were set.
    This is likely from a faulty injection, where the upstream module migrated to
    `default = promise ()`. You should do the same in your injection.
    Using the `defaultFunc` for now, as it's likely to be the one you actually
    meant.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#promises-deprecations'';

  implAndResultWarning = traceMessage ''
    Both `result` and `impl` were set.
    This is likely from a faulty injection, where the upstream module migrated
    to `result = promise ()`. You should do the same in your injection.
    Using the `impl` for now, as it's likely to be the one you actually meant.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#promises-deprecations'';

  mutatorTypeWarning = traceMessage ''
    At least one of your Adios modules used 'mutatorType' for an option. This has been deprecated, and 'type' now also
    applies to individual mutators as well. Options that use a different 'type' and 'mutatorType' should be refactored
    to use the same type.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#deprecated-mutatortype'';

  calledModuleWarning = traceMessage ''
    Calling modules directly within an Adios tree has been deprecated.
    Instead, the options for an input should be specified inside `inputs.$name.options`. The result is then stored in `results.$name`.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#new-format-for-calling-options'';

  mergeMovedWarning = traceMessage ''
    'adios.lib.merge' has been moved to 'adios.merge'.
    The new location allows `merge` to be conveniently destructured in a file's toplevel parameters.

    To see which modules need to be migrated, add `--option abort-on-warn true` to your Nix command
    of choice. This will print a proper error context and show the offending module name(s).

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#merge-moved'';

  withPrioError = throw ''
    `adios.merge.general.withPrio` has been renamed to `adios.merge.general.withOrder`
    This is because the function really sets ordering info, not priority,
    and we may wish to add a withPrio function in the future'';

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
