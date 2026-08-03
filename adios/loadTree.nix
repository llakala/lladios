# Types from adios
types:
let
  inherit (builtins)
    addErrorContext
    attrNames
    concatMap
    concatStringsSep
    filter
    foldl'
    functionArgs
    intersectAttrs
    isAttrs
    isString
    listToAttrs
    mapAttrs
    seq
    substring
    tail
    unsafeGetAttrPos
    ;

  warn = builtins.warn or builtins.trace;

  optionals = cond: list: if cond then list else [ ];

  # Call a function with only its supported attributes.
  callFunction = fn: attrs: fn (intersectAttrs (functionArgs fn) attrs);

  printList = list: "[${concatStringsSep ", " list}]";

  addWarningWithLocation =
    attrs: name: message:
    let
      loc = unsafeGetAttrPos name attrs;
    in
    if loc == null then x: x else warn "${message} in ${loc.file}:${toString loc.line}";

  # Lazy type check an attrset
  checkModuleAttributes =
    check: errorPrefix: attrs:
    if isAttrs attrs then
      mapAttrs (
        name: value: addErrorContext errorPrefix (addErrorContext "in attribute '${name}'" (check value))
      ) attrs
    else
      addErrorContext errorPrefix (throw (types.attrs.explain attrs));

  checkOptions = checkModuleAttributes types.modules.option.check;
  checkInputs = checkModuleAttributes types.modules.input.check;
  checkMutations = checkModuleAttributes types.modules.mutation.check;
  checkTypedefs = checkModuleAttributes types.modules.typedef.check;
  checkLib = types.modules.lib.check;
  checkImpl = types.modules.impl.check;

  # Merge lhs & rhs recursing into suboptions
  mergeOptionsUnchecked =
    options: lhs: rhs:
    lhs
    // rhs
    // listToAttrs (
      concatMap (
        optionName:
        let
          option = options.${optionName};
        in
        if option ? options then
          [
            {
              name = optionName;
              value = mergeOptionsUnchecked option.options (lhs.${optionName} or { }) (rhs.${optionName} or { });
            }
          ]
        else
          [ ]
      ) (attrNames options)
    );

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
in
# Self-reference for the result of this file
tree:
let
  # Get a module by its / delimited path from the given current path
  fetchModuleByPath =
    let
      split = builtins.split "/";
      splitOnSlashes = s: filter isString (split s);
      selectModule = foldl' (
        module: tok:
        if module ? modules.${tok} then
          module.modules.${tok}
        else
          throw ''
            Module path `${tok}` is not a child module of `${module.path}`.
            Valid children of `${module.path}`: ${printList (attrNames module.modules)}
          ''
      ) tree;
    in
    current: relpath:
    assert relpath != "";
    if relpath == "/" then
      tree
    else
      selectModule (
        # path axiomatically always starts with a slash
        tail (
          splitOnSlashes (
            # get path relative to the current directory
            if substring 0 1 relpath == "/" then relpath else toString (/. + current + "/${relpath}")
          )
        )
      );

  fetchModuleByFunction =
    let
      root = recurse tree;
      recurse =
        module:
        mapAttrs (_: recurse) module.modules
        // {
          # gross - once we've recursed to the appropriate level, we need to
          # actually get the module, but we don't want to disallow modules from
          # being named certain things.
          # instead, we store a functor that, when called, gives us the actual
          # module definition. if anyone names their module __functor, they
          # deserve what's coming to them.
          __functor = _: _: module;
        };
    in
    parent':
    let
      # be friendly to partial application, so a single parent can be reused
      # while recursing
      parent = if parent'.path == "/" then root else recurse parent';
    in
    self: inputFetcher:
    callFunction inputFetcher {
      inherit root parent;
      self = recurse self;
    } null;

  computeMutators =
    {
      modulePath,
      errorPrefix,
      name,
      option,
      params,
    }:
    let
      check =
        if option ? mutatorType then seq mutatorTypeWarning option.mutatorType.check else option.type.check;
    in
    concatMap (
      mutatorPath':
      let
        resolution = fetchModuleByPath modulePath mutatorPath';
      in
      # TODO: decide whether to error here, if a module didn't
      # mutate when it was supposed to
      if resolution ? mutations.${modulePath}.${name} then
        [
          (addErrorContext "${errorPrefix}: in mutator '${resolution.path}' of option '${name}'" (
            check (callFunction resolution.mutations.${modulePath}.${name} resolution.args)
          ))
        ]
      else
        [ ]
    ) option.mutators
    # If the mutators list is nonempty, have the value passed in eval/impl
    # stage go through the mergeFunc, under the current module's name.
    ++ optionals (params ? ${name}) [
      # TODO: improve this error message to make it clearer what "outside
      # mutator" is
      (addErrorContext "${errorPrefix}: in outside mutator of option '${name}'" (check params.${name}))
    ];

  # Compute options from defaults & provided args
  computeOptions =
    {
      # The current module
      self,
      # Defined options
      options ? self.options,
      # Computed args fixpoint
      args ? self.args,
      # why the options had to be computed
      errorContext ? "in",
      # parameters given explicitly in eval/impl stage
      params ? null,
    }:
    listToAttrs (
      concatMap (
        name:
        let
          option = options.${name};
          errorMessage = "${errorContext} '${self.path}': in option '${name}'";
        in
        # Gross hack - if you want to always go through the mergeFunc,
        # set `mutators = []`.
        if option ? mutators then
          [
            {
              inherit name;
              value = addErrorContext errorMessage (
                option.type.check (
                  callFunction option.mergeFunc (
                    args
                    // {
                      mutators = computeMutators {
                        modulePath = self.path;
                        errorPrefix = "${errorContext} '${self.path}'";
                        inherit name option params;
                      };
                    }
                  )
                )
              );
            }
          ]

        # Compute nested options
        else if option ? options then
          let
            value = computeOptions {
              inherit self args errorContext;
              inherit (option) options;
              params = params.${name} or { };
            };
          in
          # Only return a value if suboptions actually returned anything
          if value != { } then [ { inherit name value; } ] else [ ]
        # Explicitly passed value
        else if params ? ${name} then
          [
            {
              inherit name;
              value = addErrorContext errorMessage (option.type.check params.${name});
            }
          ]
        # Default value
        else if option ? default then
          [
            {
              inherit name;
              value = addErrorContext errorMessage (option.type.check option.default);
            }
          ]
        # Computed default value
        else if option ? defaultFunc then
          [
            {
              # Compute value with args fixpoint
              inherit name;
              value = addErrorContext errorMessage (option.type.check (callFunction option.defaultFunc args));
            }
          ]
        else
          [ ]
      ) (attrNames options)
    );
in
# Directly passed values for options in the eval stage
evalParams:
let
  recurse =
    fetchInput: path: def:
    let
      errorPrefix = "in definition of '${self.path}'";
      result = callFunction def.impl self.args;

      self = {
        options = checkOptions "${errorPrefix}: in attribute 'options'" (def.options or { });
        inputs = checkInputs "${errorPrefix}: in attribute 'inputs'" (def.inputs or { });
        modules = mapAttrs (name: recurse (fetchModuleByFunction self) "${path}/${name}") (
          def.modules or { }
        );
        path = if path == "" then "/" else path;

        ${if def ? types then "types" else null} =
          checkTypedefs "${errorPrefix}: in attribute 'types'" def.types;
        ${if def ? mutations then "mutations" else null} =
          checkMutations "${errorPrefix}: in attribute 'mutations'" def.mutations;
        ${if def ? lib then "lib" else null} = addErrorContext "${errorPrefix}: in attribute 'lib'" (
          checkLib def.lib
        );
        ${if def ? impl then "impl" else null} = addErrorContext "${errorPrefix}: in attribute 'impl'" (
          checkImpl def.impl
        );

        args = {
          inputs = mapAttrs (
            _: input:
            (
              if input ? from then
                fetchInput self input.from
              else
                seq modulePathWarning (
                  addWarningWithLocation input "path" "deprecated module path" (
                    fetchModuleByPath self.path input.path
                  )
                )
            ).args.options
          ) self.inputs;
          options =
            computeOptions {
              inherit self;
              ${if evalParams ? ${self.path} then "params" else null} = evalParams.${self.path};
            }
            # If the current module has an impl, include it in the computed args,
            # so the module can be called inside the tree
            // {
              ${if def ? impl then "__functor" else null} = self.__functor;
            };
        };

        ${if def ? impl then "__functor" else null} =
          _: implParams:
          if implParams == { } then
            # Reuse existing args if impl isn't being passed anything new
            result
          else
            let
              # Recompute args fixpoint with passed params
              args = {
                inherit (self.args) inputs;
                options =
                  computeOptions {
                    inherit self args;
                    inherit (self) options;
                    errorContext = "while calling";
                    params =
                      if evalParams ? ${self.path} then
                        mergeOptionsUnchecked self.options evalParams.${self.path} implParams
                      else
                        implParams;
                  }
                  # Current module necessarily defines a functor - include
                  # it in the computed args
                  // {
                    inherit (self) __functor;
                  };
              };
            in
            callFunction def.impl args;
      };
    in
    self;
in
recurse (fetchModuleByFunction (throw "Attempted to access parent of root module, but the root module has no parent!")) ""
