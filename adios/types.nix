{ korora }:

let
  inherit (builtins) isFunction isString;
  inherit (korora)
    any
    attrsOf
    function
    listOf
    new
    optionalAttr
    rename
    string
    struct
    type
    union
    ;

  typesT = attrsOf modules.typedef;

  modules = {
    typedef = korora.new (
      let
        type = union [
          function
          type
          typesT
        ];
      in
      {
        name = "typedef";
        inherit (type) verify explain;
      }
    );

    impl = function;

    normalOption =
      (struct "option" {
        inherit type;
        description = optionalAttr string;
        default = optionalAttr any;
        defaultFunc = optionalAttr function;
        mutatorType = optionalAttr type; # TODO: remove
        mergeFunc = optionalAttr function;
        mutators = optionalAttr (listOf string);
        example = optionalAttr any;
      }).override
        {
          verify =
            option:
            # at least one of these must be false
            (!option ? default || !option ? defaultFunc)
            # if mutators are set, then these must be
            && (!option ? mutators || option ? mergeFunc);
          explain =
            option:
            if option ? default && option ? defaultFunc then
              "'default' & 'defaultFunc' are mutually exclusive"
            else
              "if 'mutators' are specified, 'mergeFunc' must be as well";
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
        explain = v: if v ? options then explainSubOptions v else explainNormalOption v;
      };

    input =
      (struct "input" {
        # Note: The lack of a type for an input means no type checking done.
        type = type;
        path = korora.new {
          name = "pathstring";
          verify = isString;
        };
        from = korora.new {
          name = "from";
          verify = isFunction;
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

    mutation = attrsOf function;

    lib = union [
      function
      (attrsOf (rename "sublib" modules.lib))
    ];
  };

in
korora // { inherit modules; }
