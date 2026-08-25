/*
  A tiny & fast composable type system for Nix, in Nix.

  Named after the [little penguin](https://www.doc.govt.nz/nature/native-animals/birds/birds-a-z/penguins/little-penguin-korora/).

  # Features

  - Types
    - Primitive types (`string`, `int`, etc)
    - Polymorphic types (`union`, `attrsOf`, etc)
    - Struct types

  # Basic usage

  ## Checking (throws on error)

  Korora is primarily intended to wrap around some value with the `check`
  attribute:

  ```nix
  { korora }:
  let
    t = korora.string;
    value = 1;
  in
  t.check value
  ```

  On success, `check` returns the value that was passed in.
  On failure, it throws an error message.

  ## Inspecting (doesn't throw on error)

  For cases where it doesn't make sense to throw, the `inspect` attribute can be
  used to determine whether a typecheck passes:

  ```nix
  { korora }:
  let
    t = korora.string;
    value = 1;
    error = t.inspect value;
  in
  if error == null then
    # handle success case
  else
    # use the string error message however you wish
  ```

  On success, `inspect` returns null. On failure, it returns an error message as a string.

  ## Checking status and rationale separately

  For performance reasons, both `check` and `inspect` are implemented in terms
  of two separate internal functions - `verify` and `explain`.

  ```nix
  { korora }:
  let
    t = korora.string;
    value = 1;
  in
  if t.verify value then
    # handle success case
  else
    let
      error = t.explain value;
    in
    # use the error message however you wish
  ```

  `verify` returns true/false, which returns whether the typecheck passed.
  `explain` returns a string representing _why_ the typecheck failed. This
  function should only be called if `verify value == false`.

  This allows polymorphic types to be very fast, as they only need to call the
  `verify` functions of subtypes. `explain` is only called recursively if the
  top-level type fails.

  # Examples
  For usage examples, see [tests.nix](./tests.nix).

  # Reference
*/
let
  inherit (builtins)
    all
    any
    attrNames
    attrValues
    concatStringsSep
    elem
    elemAt
    genList
    isAttrs
    isBool
    isFloat
    isFunction
    isInt
    isList
    isPath
    isString
    length
    seq
    ;
  warn = builtins.warn or builtins.trace;

  isDerivation = value: value.type or null == "derivation";

  optionalElem = cond: e: if cond then [ e ] else [ ];

  joinKeys = list: concatStringsSep ", " (map (e: "'${e}'") list);

  toPretty = (import ./lib.nix).toPretty { indent = "    "; };

  defaultError =
    # value that failed the type check
    v: "value '${toPretty v}' failed the type check";

  fix =
    f:
    let
      x = f x;
    in
    x;

  # Find the first element in a list that fails to verify with the given type.
  # Assumes that the list has already been checked with `all`, and at least one
  # element failed the typecheck
  explainFirstFailingValue =
    # returns true/false depending on whether typecheck passed
    verify:
    # generates a custom error message for when the verify function failed
    explain:
    # list where at least one value failed the typecheck
    list:
    let
      recurse =
        i:
        let
          v = elemAt list i;
        in
        if verify v then recurse (i + 1) else explain v;
    in
    recurse 0;

  # Find the first function that fails on the given value.
  explainFirstFailingFunction =
    # each element returns true/false
    verifiers:
    # each element generates a custom error message
    explainers:
    # the value to be checked
    v:
    let
      recurse = i: if (elemAt verifiers i) v then recurse (i + 1) else (elemAt explainers i) v;
    in
    recurse 0;

  typedefWarning = warn ''
    At least one of your Adios modules used `types.typedef` or `types.typedef'`.
    These functions have been deprecated in favor of `types.new`.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#new-typedef-function
  '' null;
  nullWarning = warn ''
    At least one of your Adios typechecks returned null.
    On success, typechecks should now return a string.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#new-typedef-function
  '' null;
  stringVerifyWarning = warn ''
    At least one of your structs defined a custom `verify` function which
    returned a string. `verify` functions are now only permitted to return
    true/false. An `explain` function can be used to provide a custom error
    message.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#new-typedef-function
  '' null;

in
fix (self: {

  # Utility functions

  /*
    Declare a custom type.
  */
  new =
    {
      # Name of the type as a string
      name,
      # Verification function.
      # Returns true/false representing a success/failure.
      verify,
      # Function to generate an error message when the verify function fails.
      explain ? defaultError,
    }:
    assert isFunction verify;
    {
      inherit name verify explain;
      inspect = v: if verify v then null else "in type '${name}': ${explain v}";
      check =
        v:
        if verify v == true then
          v
        else if verify v == null then
          seq nullWarning v
        else
          throw "in type '${name}': ${explain v}";
    };

  /*
    Declare a custom type using a bool function

    Deprecated, use `types.new` instead.
  */
  typedef =
    # Name of the type as a string
    name:
    # Basic verification function returning a bool.
    verify:
    seq typedefWarning self.new {
      inherit name verify;
    };

  /*
    Declare a custom type using an optional<string> function.

    Deprecated, use `types.new` instead.
  */
  typedef' =
    # Name of the type as a string
    name:
    # Verification function returning null on success & a string with error message on error.
    verify:
    seq typedefWarning self.new {
      inherit name;
      verify =
        v:
        let
          result = verify v;
        in
        if result == true then true else false;
      explain = verify;
    };

  /*
    Basic error function. Used internally, but also useful to throw errors in a
    custom type.
  */
  typeError = defaultError;

  /*
    Used internally, but also useful in documentation generation.
  */
  toPretty = (import ./lib.nix).toPretty;

  # Primitive types

  /*
    String
  */
  string = self.new {
    name = "string";
    verify = isString;
  };

  /*
    Any
  */
  any = self.new {
    name = "any";
    verify = _: true;
  };

  /*
    Never
  */
  never = self.new {
    name = "never";
    verify = _: false;
  };

  /*
    Int
  */
  int = self.new {
    name = "int";
    verify = isInt;
  };

  /*
    Single precision floating point
  */
  float = self.new {
    name = "float";
    verify = isFloat;
  };

  /*
    Either an int or a float
  */
  number = self.new {
    name = "number";
    verify = v: isInt v || isFloat v;
  };

  /*
    Bool
  */
  bool = self.new {
    name = "bool";
    verify = isBool;
  };

  /*
    Null
  */
  null = self.new {
    name = "null";
    verify = isNull;
  };

  /*
    Attribute with undefined attribute types
  */
  attrs = self.new {
    name = "attrs";
    verify = isAttrs;
  };

  /*
    Attribute with undefined element types
  */
  list = self.new {
    name = "list";
    verify = isList;
  };

  /*
    Function
  */
  function = self.new {
    name = "function";
    verify = isFunction;
  };

  /*
    Path
  */
  path = self.new {
    name = "path";
    verify = isPath;
  };

  /*
    Value that may not technically be a path, but has path-like properties
    Either an actual path `./foo`, a derivation, or a string
  */
  pathLike = self.new {
    name = "pathLike";
    verify = v: isPath v || isDerivation v || isString v;
  };

  /*
    Derivation
  */
  derivation = self.new {
    name = "derivation";
    verify = isDerivation;
  };

  # Polymorphic types

  /*
    Type
  */
  type = self.new {
    name = "type";
    verify = v: v ? name && isString v.name && v ? verify && isFunction v.verify;
  };

  optional = warn "Adios type 'optional<t>' has been renamed to 'nullOr<t>'" self.nullOr;

  /*
    nullOr<t>
  */
  nullOr =
    # Null or t
    t:
    let
      inherit (t) verify;
    in
    self.new {
      name = "nullOr<${t.name}>";
      verify = v: v == null || verify v;
      explain = t.explain; # TODO: custom error message
    };

  /*
    listOf<t>
  */
  listOf =
    # Element type
    t:
    let
      inherit (t) verify;
    in
    self.new {
      name = "listOf<${t.name}>";
      verify = list: isList list && all verify list;
      explain =
        list:
        if !isList list then
          defaultError list
        else
          "in element: ${explainFirstFailingValue verify t.explain list}";
    };

  /*
    attrsOf<t>
  */
  attrsOf =
    # Attribute value type
    t:
    let
      inherit (t) verify;
    in
    self.new {
      name = "attrsOf<${t.name}>";
      verify = attrs: isAttrs attrs && all verify (attrValues attrs);
      explain =
        attrs:
        if !isAttrs attrs then
          defaultError attrs
        else
          explainFirstFailingValue (key: verify attrs.${key}) (
            key: "in attribute '${key}': ${t.explain attrs.${key}}"
          ) (attrNames attrs);
    };

  /*
    union<types...>
  */
  union =
    # Any of <t>
    types:
    assert isList types;
    let
      verifiers = map (t: t.verify) types;
    in
    self.new {
      name = "union<${concatStringsSep "," (map (t: t.name) types)}>";
      verify = v: any (verifier: verifier v) verifiers;
      # TODO: custom error message
    };

  /*
    either<t1,t2>

    Like 'union', but without an `any` call. Slight micro-optimization
    for types that are checked very often.
  */
  either =
    # Either t1
    t1:
    # Or t2
    t2:
    let
      verify1 = t1.verify;
      verify2 = t2.verify;
    in
    self.new {
      name = "either<${t1.name},${t2.name}>";
      verify = v: verify1 v || verify2 v;
    };

  /*
    intersection<types...>
  */
  intersection =
    # All of <t>
    types:
    assert isList types;
    let
      verifiers = map (t: t.verify) types;
    in
    self.new {
      name = "intersection<${concatStringsSep "," (map (t: t.name) types)}>";
      verify = v: all (verifier: verifier v) verifiers;
      # TODO: custom explain message
    };

  /*
    both<t1,t2>

    Like 'intersection', but without an `all` call. Slight micro-optimization
    for types that are checked very often.
  */
  both =
    # Both t1
    t1:
    # And t2
    t2:
    let
      verify1 = t1.verify;
      verify2 = t2.verify;
    in
    self.new {
      name = "all<${t1.name},${t2.name}>";
      verify = v: verify1 v && verify2 v;
    };


  /*
    rename<name, type>

    Because some polymorphic types such as attrsOf inherits names from it's
    sub-types we need to erase the name to not cause infinite recursion.

    #### Example:
    ```nix
    myType = types.attrsOf (
      types.rename "eitherType" (types.union [
        types.string
        myType
      ])
    );
    ```
  */
  rename =
    name: type:
    # TODO: properly handle optionalAttr
    self.new {
      inherit name;
      inherit (type) verify explain;
    };

  /*
    struct<name, members...>

    #### Example
    ```nix
    korora.struct "myStruct" {
      foo = types.string;
    }
    ```

    ### Features

    #### Totality

    By default, all attribute names must be present in a struct. It is possible to override this by specifying _totality_. Here is how to do this:
    ```nix
    (korora.struct "myStruct" {
      foo = types.string;
    }).override { total = false; }
    ```

    This means that a `myStruct` struct can have any of the keys omitted. Thus these are valid:
    ```nix
    let
      s1 = { };
      s2 = { foo = "bar"; }
    in ...
    ```

    #### Unknown attribute names

    By default, unknown attribute names are not allowed.

    It is possible to override this by specifying `unknown` on struct creation:
    ```nix
    (korora.struct "myStruct" {
      foo = types.string;
    }).override { unknown = true; }
    ```

    This means that
    ```nix
    {
      foo = "bar";
      baz = "hello";
    }
    ```
    is normally invalid, but works when `unknown` is set to `true`.

    Because Nix lacks primitive operations to iterate over attribute sets dynamically without
    allocation this function allocates one intermediate attribute set per struct verification.

    #### Custom invariants

    Custom struct verification functions can be added as such:
    ```nix
    (types.struct "testStruct2" {
      x = types.int;
      y = types.int;
    }).override {
      verify = v: if v.x + v.y == 2 then "VERBOTEN" else null;
    };
    ```

    #### Function signature
  */
  struct =
    # Name of struct type as a string
    name':
    # Attribute set of type definitions.
    types:
    assert isAttrs types;
    let
      names = attrNames types;

      mkStruct' =
        {
          total ? true,
          unknown ? false,
          verify ? null,
          explain ? null,
        }:
        assert isBool total;
        assert isBool unknown;
        assert verify != null -> isFunction verify;
        assert explain != null -> isFunction explain;
        let
          verifiers =
            map (
              attr:
              let
                inherit (types.${attr}) verify;
              in
              if types.${attr}.__optional or (!total) then
                v: !v ? ${attr} || verify v.${attr}
              else
                v: v ? ${attr} && verify v.${attr}
            ) names
            ++ optionalElem (!unknown) (v: removeAttrs v names == { })
            ++ optionalElem (verify != null) (
              v:
              let
                result = verify v;
              in
              # most users don't interact with types.new at all, so this is the
              # most likely place to encounter a deprecated verify -> string
              if isString result then seq stringVerifyWarning false else result
            );
        in
        self.new {
          name = "struct<${name'}>";
          verify = v: isAttrs v && all (verifier: verifier v == true) verifiers;
          explain =
            v:
            if !isAttrs v then
              defaultError v
            else
              let
                explainers =
                  map (
                    attr:
                    let
                      type = types.${attr};
                    in
                    if type.__optional or (!total) then
                      v: "in member '${attr}' of type '${type.name}': ${type.explain v.${attr}}"
                    else
                      v:
                      if !v ? ${attr} then
                        "missing member '${attr}'"
                      else
                        "in member '${attr}' of type '${type.name}': ${type.explain v.${attr}}"
                  ) names
                  ++ optionalElem (!unknown) (
                    v:
                    "keys [${joinKeys (attrNames (removeAttrs v names))}] are unrecognized, expected keys are [${joinKeys names}]"
                  )
                  ++ optionalElem (verify != null) (
                    if explain != null then
                      v: explain v
                    else
                      v: "custom verification function failed on value '${toPretty v}'"
                  );
              in
              explainFirstFailingFunction verifiers explainers v;
        }
        // {
          override = mkStruct';
        };
    in
    mkStruct' { };

  /*
    optionalAttr<t>
  */
  optionalAttr =
    let
      makeOptional = {
        __optional = true;
      };
    in
    t:
    self.new {
      name = "optionalAttr<${t.name}>";
      inherit (t) verify explain;
    }
    // makeOptional;

  /*
    enum<name, elems...>
  */
  enum =
    # Name of enum type as a string
    name:
    # List of allowable enum members
    elems:
    assert isList elems;
    self.new {
      inherit name;
      verify = v: elem v elems;
      explain = v: "'${toPretty v}' is not a member of enum '${name}'";
    };

  /*
    tuple<elems...>
  */
  tuple =
    # List of tuple member types
    types:
    assert isList types;
    let
      len = length types;
      verifiers = genList (i: v: (elemAt types i).verify (elemAt v i)) len;
    in
    self.new {
      name = "tuple<${concatStringsSep "," (map (t: t.name) types)}>";
      verify = v: isList v && length v == len && all (verifier: verifier v) verifiers;
      explain =
        tuple:
        if !isList tuple then
          defaultError tuple
        else if length tuple != len then
          "expected tuple of length ${toString len} but value '${toPretty tuple}' has length ${toString (length tuple)}"
        else
          let
            explainers = genList (
              i:
              let
                type = elemAt types i;
              in
              v: "in element ${toString i} of type '${type.name}': ${type.explain (elemAt v i)}"
            ) len;
          in
          explainFirstFailingFunction verifiers explainers tuple;
    };

  /*
    Create a wrapped type checked function.
  */
  defun =
    name: paramTypes: resultType:
    let
      verifyFuncs = map (type: type.verify) paramTypes;
      len = length paramTypes;
      recurse =
        i: acc:
        if i != len then
          # more parameters need to be passed to the function
          let
            verify = elemAt verifyFuncs i;
          in
          value:
          if verify value then
            recurse (i + 1) (acc value)
          else
            let
              type = elemAt paramTypes i;
            in
            throw "in argument ${toString i}: ${type.explain value}"
        else
        # all parameters have been passed, check return value
        if resultType.verify acc then
          acc
        else
          throw "in return type: ${resultType.explain acc}";
    in
    recurse 0;
})
