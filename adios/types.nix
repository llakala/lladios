{ korora }:

let
  inherit (builtins) isFunction isString;
  inherit (korora)
    any
    attrs
    attrsOf
    bool
    either
    function
    listOf
    new
    optionalAttr
    string
    struct
    type
    ;

  # TODO: do any of these actually need the verifyNested treatment?
  # Do they take in user-supplied types?
  # If not, note down why they aren't getting it.
  modules = {
    types = attrsOf (
      either type (
        modules.types.override {
          name = "subtypedef";
          apply = null;
        }
      )
    );

    # TODO: is specifying resolve here faster than only checking for the promise attribute?
    # TODO: should this go elsewhere?
    # TODO: any more-efficient struct overrides?
    promise = struct "promise" {
      __adiosPromise = bool;
      resolve = function;
    };

    normalOption =
      (struct "option" {
        # TODO: benchmark new type against pre-promise types, optimise
        type = either type modules.promise;
        description = string;
        default = any;
        defaultFunc = function; # deprecated
        mutatorType = type; # deprecated
        mergeFunc = function;
        merge = function;
        mutators = listOf string;
        example = any;
      }).override
        {
          # since most attributes are rarely specified, we opt into the lazier
          # algorithm, and manually verify that `type` is specified
          total = false;
          verify =
            option:
            option ? type
            # if mutators are set, then merge XOR mergeFunc must be set
            && (!option ? mutators || (option ? merge != option ? mergeFunc));
          explain =
            option:
            if !option ? type then
              "missing member 'type'"
            else if !option ? merge && !option ? mergeFunc then
              "if 'mutators' are specified, 'merge' must be as well"
            else
              "'merge' and 'mergeFunc' are disjoint, and 'mergeFunc' is deprecated";
        };

    subOptions = struct "subOptions" {
      options = attrsOf modules.option;
      description = optionalAttr string;
      example = optionalAttr any;
    };

    # to make sure custom error messages are preserved, we don't use types.union
    # from korora, and instead choose which type to use based on whether the
    # option contains sub-options
    option =
      let
        verifyNormalOption = modules.normalOption.verify;
        explainNormalOption = modules.normalOption.explain;
        verifySubOptions = modules.subOptions.verify;
        explainSubOptions = modules.subOptions.explain;
      in
      new {
        name = "option";
        verify = v: if v ? options then verifySubOptions v else verifyNormalOption v;
        apply = null;
        explain = v: if v ? options then explainSubOptions v else explainNormalOption v;
      };

    input =
      (struct "input" {
        # Note: The lack of a type for an input means no type checking done.
        # TODO: should inputs use their module's type by default?
        inherit type;
        path = korora.new {
          name = "pathstring";
          verify = isString;
          apply = null;
        };
        options = attrs;
        from = korora.new {
          name = "from";
          verify = isFunction;
          apply = null;
        };
      }).override
        {
          total = false; # all attributes are optional, the verify function handles one being set
          verify = attrs: attrs ? path != attrs ? from;
          explain =
            attrs:
            if attrs ? path && attrs ? from then
              "'path' and 'from' are disjoint for a given input"
            else
              "either 'path' or 'from' must be specified for a given input";
        };

    mutation = attrs;

    lib = attrsOf (
      either function (
        modules.lib.override {
          name = "sublib";
          apply = null;
        }
      )
    );

    assertions = listOf (
      struct "assertion" {
        verify = function;
        explain = function;
      }
    );
  };

in
korora // { inherit modules; }
