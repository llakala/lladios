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
    typedef = korora.new {
      name = "typedef";
      verify =
        (union [
          function
          type
          typesT
        ]).verify;
    };

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
            if option ? default && option ? defaultFunc then
              "'default' & 'defaultFunc' are mutually exclusive"
            else if option ? mutatorType != option ? mergeFunc then
              "if either 'mutatorType' or 'mergeFunc' is specified, the other must be as well"
            else if option ? mutators && !(option ? mergeFunc && option ? mutatorType) then
              "if 'mutators' are specified, 'mergeFunc' and 'mutatorType' must be as well"
            else
              true;
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
          verify =
            attrs:
            if attrs ? path && attrs ? from then
              "'path' and 'from' are disjoint for a given input"
            else if !attrs ? from && !attrs ? path then
              "either 'path' or 'from' must be specified for a given input"
            else
              true;
        };

    mutation = attrsOf function;

    lib = union [
      function
      (attrsOf (rename "sublib" modules.lib))
    ];
  };

in
korora // { inherit modules; }
