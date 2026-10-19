# Types from adios
types:
let
  inherit (builtins)
    addErrorContext
    all
    attrNames
    concatMap
    concatStringsSep
    filter
    foldl'
    functionArgs
    intersectAttrs
    isAttrs
    isFunction
    isString
    listToAttrs
    mapAttrs
    seq
    split
    substring
    tail
    ;

  warn = builtins.warn or builtins.trace;

  # call a function/promise with only its supported attributes
  # we call a bunch of functions with the same args, and re-call one function with
  # lots of different args. partially apply for both cases!
  callFunctionWith = args: fn: fn (intersectAttrs (functionArgs fn) args);
  callCachedFunction =
    fn:
    let
      intersectFargs = intersectAttrs (functionArgs fn);
    in
    args: fn (intersectFargs args);

  callPromiseWith =
    args: promise:
    if promise ? awaiters then
      foldl' (
        prev: await:
        let
          result = await prev;
        in
        if result.__adiosPromise or false then
          result.resolve (intersectAttrs (functionArgs result.resolve) args)
        else
          result
      ) (promise.resolve (intersectAttrs (functionArgs promise.resolve) args)) promise.awaiters
    else
      promise.resolve (intersectAttrs (functionArgs promise.resolve) args);
  callCachedPromise =
    promise:
    let
      intersectFargs = intersectAttrs (functionArgs promise.resolve);
    in
    if promise ? awaiters then
      args:
      foldl' (
        prev: await:
        let
          result = await prev;
        in
        if result.__adiosPromise or false then
          result.resolve (intersectAttrs (functionArgs result.resolve) args)
        else
          result
      ) (promise.resolve (intersectFargs args)) promise.awaiters
    else
      args: promise.resolve (intersectFargs args);

  printList = list: "[${concatStringsSep ", " list}]";

  # Lazy type check an attrset
  checkModuleAttributes =
    check: context: attrs:
    if isAttrs attrs then
      mapAttrs (
        name: value: addErrorContext context (addErrorContext "in attribute '${name}'" (check value))
      ) attrs
    else
      addErrorContext context (throw (types.attrs.explain attrs));

  checkOptions = checkModuleAttributes types.modules.option.check;
  checkInputs = checkModuleAttributes types.modules.input.check;
  checkMutations = checkModuleAttributes types.modules.mutation.check;
  checkTypedefs = types.modules.types.check;
  checkLib = types.modules.lib.check;
  checkAssertions = types.modules.assertions.check;

  # NOTE: assertions are currently run upon trying to access `args`, not
  # `args.options`. This means even if only `args.inputs` are accessed,
  # assertions still run. This is technically less lazy than it could be, but
  # changing it would be a very minor performance regression. Consider fixing.
  runAssertions' =
    errorPrefix: callFunction: self: v:
    assert all (
      assertion:
      callFunction assertion.verify
      || addErrorContext "${errorPrefix} module '${self.path}': while verifying 'assertions':" (
        throw (callFunction assertion.explain)
      )
    ) self.assertions;
    v;
  runAssertionsAndDefine = runAssertions' "in";
  runAssertionsAndCall = runAssertions' "while calling";

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
  messages = import ./messages.nix { inherit printList; };
in
# Self-reference for the result of this file
tree:
let
  # Get a module by its / delimited path from the given current path
  fetchModuleByPath =
    let
      splitOnSlashes = split "/";
      filterStrings = filter isString;
      firstCharacter = substring 0 1;
      selectModule = foldl' (
        module: tok:
        module.modules.${tok} or (throw ''
          Module path `${tok}` is not a child module of `${module.path}`.
          Valid children of `${module.path}`: ${printList (attrNames module.modules)}
        '')
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
          filterStrings (
            splitOnSlashes (
              # get path relative to the current directory
              if firstCharacter relpath == "/" then relpath else toString (/. + current + "/${relpath}")
            )
          )
        )
      );

  fetchInput =
    let
      root = recurse tree;
      recurse =
        module:
        mapAttrs (_: recurse) module.modules
        // {
          # gross - once we've recursed to the appropriate level, we need to
          # actually get the module, but we don't want to disallow modules from
          # being named whatever we choose.
          # as a least-bad solution, we choose to store the actual module under
          # a name that's unlikely to be set
          __fetchedAdiosModule = module;
        };
      parentFargs = {
        parent = false;
      };
    in
    parent:
    let
      parentArgs = {
        parent = recurse parent;
      };
    in
    self:
    let
      callInput = callFunctionWith {
        inherit root;
        parent = parentArgs.parent;
        self = recurse self;
      };
    in
    _:
    { from, ... }@inputParams:
    if from == null then
      seq messages.modulePathWarning (
        warn "deprecated module path in ${self.path}" (fetchModuleByPath self.path inputParams.path)
      )
    else if functionArgs from == parentFargs then
      # optimize for the common case where functionArgs is just `{ parent }:`
      (from parentArgs).__fetchedAdiosModule
    else
      (callInput from).__fetchedAdiosModule;

  computeMutators' =
    errorPrefix:
    {
      self,
      args,
      name,
      option,
      params,
    }:
    let
      check =
        if option ? mutatorType then
          seq messages.mutatorTypeWarning option.mutatorType.check
        else
          option.type.check;
    in
    concatMap (
      mutatorPath:
      let
        resolution = fetchModuleByPath self.path mutatorPath;
        # if a module mutates itself and sets something in the impl stage,
        # it needs access to the newest version of args, not the cached one
        args' = if self.path == mutatorPath then args else resolution.args;
        mutations = resolution.mutations.${self.path};
      in
      if mutations ? ${name} then
        [
          (addErrorContext
            "${errorPrefix} '${self.path}': in mutator '${resolution.path}' of option '${name}'"
            (
              check (
                if mutations.${name}.__adiosPromise or false then
                  callPromiseWith args' mutations.${name}
                else if isFunction mutations.${name} then
                  seq messages.mutationFunctionWarning (
                    warn "mutation was function in ${self.path}.mutations.${mutatorPath}.${name}" (
                      callFunctionWith args' mutations.${name}
                    )
                  )
                else
                  mutations.${name}
              )
            )
          )
        ]
      else
        warn
          "'${self.path}': mutator '${resolution.path}' of option '${name}' was expected to provide a mutation. hint: did you make a typo?"
          [ ]
    ) option.mutators
    # If the mutators list is nonempty, have the value passed in eval/impl
    # stage go through the mergeFunc, under the current module's name.
    ++ (
      if params ? ${name} then
        [
          # TODO: improve this error message to make it clearer what "outside
          # mutator" is
          (addErrorContext "${errorPrefix} '${self.path}': in outside mutator of option '${name}'" (
            check params.${name}
          ))
        ]
      else
        [ ]
    );

  # Compute options from defaults & provided args
  computeOptions' =
    # why the options had to be computed
    errorPrefix:
    let
      computeMutators = computeMutators' errorPrefix;
    in
    {
      # The current module
      self,
      # Computed args fixpoint
      args,
      # Defined options
      options ? self.options,
      # parameters given explicitly in eval/impl stage
      params ? { },
      # calls the given promise (pre-applied with `args`)
      callPromise,
    }:
    let
      names = attrNames options;
    in
    assert
      params == { }
      || removeAttrs params names == { }
      || messages.mkMissingParamsError self errorPrefix options params;
    listToAttrs (
      concatMap (
        name:
        let
          option = options.${name};
          context = "${errorPrefix} '${self.path}': in option '${name}'";
        in
        # Gross hack - if you want to always go through the mergeFunc,
        # set `mutators = []`.
        if option ? mutators then
          [
            {
              inherit name;
              value = addErrorContext context (
                option.type.check (
                  callFunctionWith (
                    args
                    // {
                      mutators = computeMutators {
                        inherit
                          args
                          name
                          option
                          params
                          self
                          ;
                      };
                    }
                  ) option.mergeFunc
                )
              );
            }
          ]

        # Compute nested options
        else if option ? options then
          let
            value = computeOptions' errorPrefix {
              inherit
                args
                callPromise
                self
                ;
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
              value = addErrorContext context (option.type.check params.${name});
            }
          ]
        else if option ? defaultFunc then
          (
            v:
            if option ? default then
              seq messages.defaultFuncAndDefaultWarning (warn "defaultFunc AND default in ${self.path}.${name}" v)
            else
              seq messages.defaultFuncOnlyWarning (warn "defaultFunc in ${self.path}.${name}" v)
          )
            [
              {
                inherit name;
                value = addErrorContext context (option.type.check (callFunctionWith args option.defaultFunc));
              }
            ]
        # default value
        else if option ? default then
          [
            {
              inherit name;
              value = addErrorContext context (
                option.type.check (
                  if option.default.__adiosPromise or false then callPromise option.default else option.default
                )
              );
            }
          ]
        else
          [ ]
      ) names
    );
  computeCachedOptions = computeOptions' "in";
  recomputeOptions = computeOptions' "while calling";
in
# Directly passed values for options in the eval stage
evalParams:
let
  recurse =
    # fetchInput partially applied on `parent`
    fetchInput':
    # path to the parent module
    parentPath:
    # the current module's name
    moduleName:
    # unchecked module definition
    def:
    let
      errorPrefix = "in definition of '${self.path}'";
      currentFunctor = {
        ${if self ? result then "__functor" else null} =
          _: v: seq messages.calledModuleWarning (warn "tried to call module '${self.path}'" (self v));
      };

      callPromise = callPromiseWith args;

      inputModules = mapAttrs (fetchInput' self) self.inputs;
      # if inputs.${name} has no custom options, reuse the input's cached args
      # if we do specify non-empty options, recompute!
      inputArgs = mapAttrs (
        name:
        {
          options ? { },
          ...
        }:
        if options == { } then
          inputModules.${name}.args
        else
          inputModules.${name}.recomputeArgs (
            if options.__adiosPromise or false then callPromise options else options
          )
      ) self.inputs;

      # compute args before running assertions to prevent infrec
      args = {
        inputs = mapAttrs (
          name: args:
          if !args ? result then
            args.options
          else
            args.options
            // {
              # improves the error message by showing where it was called
              __functor =
                _: v:
                seq messages.calledModuleWarning (
                  warn "module '${self.path}' tried to call '${inputModules.${name}.path}'" (inputModules.${name} v)
                );
            }
        ) inputArgs;
        results = mapAttrs (
          name: args:
          args.result
            or (throw "module '${self.path}' tried to access results.${name}, but input module '${inputModules.${name}.path}' has no result")
        ) inputArgs;
        # uses self.args to also run assertions
        ${if self ? result then "result" else null} = self.result self.args;
        options =
          computeCachedOptions {
            inherit self args callPromise;
            ${if evalParams ? ${self.path} then "params" else null} = evalParams.${self.path};
          }
          // currentFunctor;
      };

      self = {
        options = checkOptions "${errorPrefix}: in attribute 'options'" (def.options or { });
        inputs = checkInputs "${errorPrefix}: in attribute 'inputs'" (def.inputs or { });
        path = "${parentPath}/${moduleName}";
        modules = mapAttrs (
          # apply the equivalent of `fetchInput parent` here, so the partial
          # function is cached for all children
          recurse (fetchInput self) (if self.path == "/" then "" else self.path)
        ) (def.modules or { });
        args =
          if !self ? assertions then args else runAssertionsAndDefine (callFunctionWith args) self args;

        ${if def ? types then "types" else null} = addErrorContext "${errorPrefix}: in attribute 'types'" (
          checkTypedefs def.types
        );
        ${if def ? mutations then "mutations" else null} =
          checkMutations "${errorPrefix}: in attribute 'mutations'" def.mutations;
        ${if def ? lib then "lib" else null} = addErrorContext "${errorPrefix}: in attribute 'lib'" (
          checkLib def.lib
        );
        ${if def ? assertions && def.assertions != [ ] then "assertions" else null} =
          addErrorContext "${errorPrefix}: in attribute 'assertions'" (checkAssertions def.assertions);

        # calling this with some args fixpoint returns the module's result
        ${if def ? result || def ? impl then "result" else null} =
          if def ? impl then
            if def ? result then
              seq messages.implAndResultWarning (
                warn "impl AND result in ${self.path}" (callCachedFunction def.impl)
              )
            else
              seq messages.implOnlyWarning (warn "impl in ${self.path}" (callCachedFunction def.impl))
          else if def.result.__adiosPromise or false then
            callCachedPromise def.result
          else
            _: def.result;

        # calling this with some params computes a new `args` fixpoint
        recomputeArgs =
          params:
          let
            callPromise = callPromiseWith newArgs;
            # if inputs.${name}.options is non-empty, recompute each input's
            # args, since if inputs.${name} was a promise, it could return a new
            # value
            # we could reuse the previous inputArgs for non-promises, but that'd
            # force the default args to always be computed, which is worse than
            # only recomputing unnecessarily on non-promise inputs.${name}.options
            inputArgs = mapAttrs (
              name:
              {
                options ? { },
                ...
              }:
              if options == { } then
                inputModules.${name}.args
              else
                inputModules.${name}.recomputeArgs (
                  if options.__adiosPromise or false then callPromise options else options
                )
            ) self.inputs;
            newArgs = {
              inputs = mapAttrs (
                name: args:
                if !args ? result then
                  args.options
                else
                  args.options
                  // {
                    # improves the error message by showing where it was called
                    __functor =
                      _: v:
                      seq messages.calledModuleWarning (
                        warn "module '${self.path}' tried to call '${inputModules.${name}.path}'" (inputModules.${name} v)
                      );
                  }
              ) inputArgs;
              results = mapAttrs (
                name: args:
                args.result
                  or (throw "module '${self.path}' tried to access 'results.${name}', but input module '${inputModules.${name}.path}' has no result")
              ) inputArgs;
              ${if self ? result then "result" else null} = self.result newArgs;
              options =
                recomputeOptions {
                  inherit self callPromise;
                  args = newArgs;
                  params =
                    if evalParams ? ${self.path} then
                      mergeOptionsUnchecked self.options evalParams.${self.path} params
                    else
                      params;
                }
                // currentFunctor;
            };
          in
          if !self ? assertions then
            newArgs
          else
            runAssertionsAndCall (callFunctionWith newArgs) self newArgs;

        # given some set of params, compute a new args fixpoint, then call
        # self.result with those args
        ${if def ? result || def ? impl then "__functor" else null} =
          _: implParams:
          if implParams == { } then
            # Reuse existing args if impl isn't being passed anything new
            self.args.result
          else
            (self.recomputeArgs implParams).result;

      };
    in
    assert isAttrs def || messages.mkBadDefError self.path def;
    self;
in
recurse (fetchInput (
  throw "Attempted to access parent of root module, but the root module has no parent!"
)) "" ""
