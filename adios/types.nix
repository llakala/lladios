{ korora }:

let
  inherit (builtins) isFunction isString;
  inherit (korora)
    any
    attrsOf
    function
    listOf
    never
    optionalAttr
    string
    struct
    type
    typedef
    typedef'
    union
    ;

  neverAttr = optionalAttr never;

  typesT = attrsOf modules.typedef;

  modules = {
    typedef =
      typedef' "typedef"
        (union [
          function
          type
          typesT
        ]).verify;

    nonMutableOption =
      (struct "option" {
        inherit type;
        description = optionalAttr string;
        default = optionalAttr any;
        defaultFunc = optionalAttr function;
        example = optionalAttr any;
      }).override
        {
          verify =
            option:
            if option ? default && option ? defaultFunc then
              "'default' & 'defaultFunc' are mutually exclusive"
            else
              null;
        };

    mutableOption = struct "mutableOption" {
      inherit type;
      mutators = optionalAttr (listOf string);
      mutatorType = type;
      mergeFunc = function;
      description = optionalAttr string;
      example = optionalAttr any;
      default = optionalAttr any;
      defaultFunc = optionalAttr function;
    };

    subOptions = struct "subOptions" {
      options = attrsOf modules.option;
      description = optionalAttr string;
      # Make fields used for normal options non-permitted
      type = neverAttr;
      default = neverAttr;
      defaultFunc = neverAttr;
    };

    option = union [
      modules.nonMutableOption
      modules.mutableOption
      modules.subOptions
    ];

    input =
      (struct "input" {
        # Note: The lack of a type for an input means no type checking done.
        type = optionalAttr type;
        path = optionalAttr (typedef "pathstring" isString);
        from = optionalAttr (typedef "from" isFunction);
      }).override
        {
          verify =
            attrs:
            if attrs ? path && attrs ? from then
              "'path' and 'from' are disjoint for a given input"
            else if !attrs ? path && !attrs ? from then
              "either 'path' or 'from' must be specified for a given input"
            else
              null;
        };

    mutation = attrsOf function;

    lib = union [
      function
      (attrsOf modules.lib)
    ];
  };

in
korora // { inherit modules; }
