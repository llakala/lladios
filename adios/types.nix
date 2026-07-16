{ korora }:

let
  inherit (builtins) isFunction isString;
  inherit (korora)
    any
    attrsOf
    function
    listOf
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
        mutatorType = optionalAttr type;
        mergeFunc = optionalAttr function;
        mutators = optionalAttr (listOf string);
        example = optionalAttr any;
      }).override
        {
          verify =
            option:
            # at least one of these must be false
            (!option ? default || !option ? defaultFunc)
            # if one is defined, the other must be
            && (option ? mutatorType == option ? mergeFunc)
            # if mutators are set, then these must be
            && (!option ? mutators || option ? mutatorType && option ? mergeFunc);
          explain =
            option:
            if option ? default && option ? defaultFunc then
              "'default' & 'defaultFunc' are mutually exclusive"
            else if option ? mutatorType != option ? mergeFunc then
              "if either 'mutatorType' or 'mergeFunc' is specified, the other must be as well"
            else
              "if 'mutators' are specified, 'mergeFunc' and 'mutatorType' must be as well";
        };

    subOptions = struct "subOptions" {
      options = attrsOf modules.option;
      description = optionalAttr string;
      example = optionalAttr any;
    };

    option = union [
      modules.normalOption
      modules.subOptions
    ];

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
