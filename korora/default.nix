/*
  A tiny & fast composable type system for Nix, in Nix.

  Named after the [little penguin](https://www.doc.govt.nz/nature/native-animals/birds/birds-a-z/penguins/little-penguin-korora/).

  # Features

  - Types
    - Primitive types (`string`, `int`, etc)
    - Polymorphic types (`union`, `attrsOf`, etc)
    - Struct types

  # Basic usage

  - Verification

  Basic verification is done with the type function `verify`:

  ```nix
  { korora }:
  let
    t = korora.string;
    value = 1;

    # Error contains the string "Expected type 'string' but value '1' is of type 'int'"
    valid = t.verify 1;
  in
  if valid == true then value else throw valid
  ```

  On success, `verify` returns true.
  On failure, it returns an error message.

  - Checking (assertions)

  For convenience you can also check a value on-the-fly:

  ```nix
  { korora }:
  let
    t = korora.string;
    value = 1;

    # Same error as previous example, but `check` throws.
    result = t.check value;
  in
  result
  ```

  On success, `check` returns the value that was passed in.
  On failure, it throws an error message.

  # Examples
  For usage example see [tests.nix](./tests.nix).

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
    foldl'
    head
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
    split
    ;
  warn = builtins.warn or builtins.trace;

  isDerivation = value: value.type or null == "derivation";

  optionalElem = cond: e: if cond then [ e ] else [ ];

  joinKeys = list: concatStringsSep ", " (map (e: "'${e}'") list);

  toPretty = (import ./lib.nix).toPretty { indent = "    "; };

  typeError =
    # Name of the type as a string
    name:
    # value that failed the type check
    v:
    "Expected type '${name}' but value '${toPretty v}' failed the type check";

  fix =
    f:
    let
      x = f x;
    in
    x;

  addTypedefWarning = warn ''
    At least one of your Adios modules used `types.typedef` or `types.typedef'`.
    These functions have been deprecated in favor of `types.new`.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#new-typedef-function
  '' null;
  addNullWarning = warn ''
    At least one of your Adios typechecks returned null.
    On success, typechecks should now return a string.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#new-typedef-function
  '' null;

in
fix (self: {

  # Utility functions

  /*
    Declare a custom type using a bool function
  */
  typedef =
    # Name of the type as a string
    name:
    # Basic verification function returning a bool.
    verify:
    seq addTypedefWarning self.new {
      inherit name verify;
    };

  /*
    Declare a custom type using an optional<string> function.
  */
  typedef' =
    # Name of the type as a string
    name:
    # Verification function returning null on success & a string with error message on error.
    verify:
    seq addTypedefWarning self.new {
      inherit name verify;
    };

  /*
    Declare a custom type.
    Must either be passed a `validate` or `verify` function.
  */
  new =
    {
      # Name of the type as a string
      name,
      # Verification function.
      # Returns true on success and false on failure.
      # To return a custom error message, return a string.
      verify,
    }:
    assert isFunction verify;
    {
      inherit name;
      __name = head (split "<" name);
      verify =
        v:
        let
          result = verify v;
        in
        if result == true then
          true
        else if result == false then
          typeError name v
        else if isString result then
          result
        else
          assert result == null;
          seq addNullWarning true;
      check =
        v:
        let
          result = verify v;
        in
        if result == true then
          v
        else if result == false then
          throw (typeError name v)
        else if isString result then
          throw result
        else
          assert result == null;
          seq addNullWarning v;
    };

  /*
    Basic error function. Used internally, but also useful to throw errors in a
    custom type.
  */
  typeError = typeError;

  /*
    Used internally, but also useful in documentation generation.
  */
  toPretty = (import ./lib.nix).toPretty;

  /*
    Find the first element in a list that fails the given typecheck function.
    Assumes that:
    - the list has already been checked with `all`, and at least one element failed the typecheck
  */
  findFirstError =
    # function to be called on every element of the list
    verify:
    # list where at least one value failed the typecheck
    list:
    let
      recurse =
        i:
        let
          v = elemAt list i;
        in
        if verify v == true then recurse (i + 1) else verify v;
    in
    recurse 0;

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

  optional =
    (builtins.warn or builtins.trace) "Adios type 'optional<t>' has been renamed to 'nullOr<t>'"
      self.nullOr;

  /*
    nullOr<t>
  */
  nullOr =
    # Null or t
    t:
    let
      name = "nullOr<${t.name}>";
      inherit (t) verify;
    in
    self.new {
      inherit name;
      verify =
        v:
        if v == null then
          true
        else if verify v == true then
          true
        else
          "in ${name}: ${verify v}";
    };

  /*
    listOf<t>
  */
  listOf =
    # Element type
    t:
    let
      name = "listOf<${t.name}>";
      inherit (t) verify;
    in
    self.new {
      inherit name;
      verify =
        list:
        if !isList list then
          typeError name list
        else if all (elem: verify elem == true) list then
          true
        else
          # If an error was found, run the checks again to find the first error to return.
          "in ${name} element: ${self.findFirstError verify list}";
    };

  /*
    attrsOf<t>
  */
  attrsOf =
    # Attribute value type
    t:
    let
      name = "attrsOf<${t.name}>";
      inherit (t) verify;
    in
    self.new {
      inherit name;
      verify =
        attrs:
        if !isAttrs attrs then
          typeError name attrs
        else if all (value: verify value == true) (attrValues attrs) then
          true
        else
          self.findFirstError (
            key:
            if verify attrs.${key} == true then
              true
            else
              "in ${name} value: in attribute '${key}': ${verify attrs.${key}}"
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
      funcs = map (t: t.verify) types;
    in
    self.new {
      name = "union<${concatStringsSep "," (map (t: t.name) types)}>";
      verify = v: any (func: func v == true) funcs;
    };

  /*
    intersection<types...>
  */
  intersection =
    # All of <t>
    types:
    assert isList types;
    let
      funcs = map (t: t.verify) types;
    in
    self.new {
      name = "intersection<${concatStringsSep "," (map (t: t.name) types)}>";
      verify = v: all (func: func v == true) funcs;
    };

  /*
    rename<name, type>

    Because some polymorphic types such as attrsOf inherits names from it's
    sub-types we need to erase the name to not cause infinite recursion.

    #### Example:
    ``` nix
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
      inherit (type) verify;
    };

  /*
    struct<name, members...>

    #### Example
    ``` nix
    korora.struct "myStruct" {
      foo = types.string;
    }
    ```

    #### Features

    - Totality

    By default, all attribute names must be present in a struct. It is possible to override this by specifying _totality_. Here is how to do this:
    ``` nix
    (korora.struct "myStruct" {
      foo = types.string;
    }).override { total = false; }
    ```

    This means that a `myStruct` struct can have any of the keys omitted. Thus these are valid:
    ``` nix
    let
      s1 = { };
      s2 = { foo = "bar"; }
    in ...
    ```

    - Unknown attribute names

    By default, unknown attribute names are not allowed.

    It is possible to override this by specifying `unknown` on struct creation:
    ```nix
    (korora.struct "myStruct" {
      foo = types.string;
    }).override { unknown = true; }
    ```

    This means that
    ``` nix
    {
      foo = "bar";
      baz = "hello";
    }
    ```
    is normally invalid, but works when `unknown` is set to `true`.

    Because Nix lacks primitive operations to iterate over attribute sets dynamically without
    allocation this function allocates one intermediate attribute set per struct verification.

    - Custom invariants

    Custom struct verification functions can be added as such:
    ``` nix
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
    name:
    # Attribute set of type definitions.
    members:
    assert isAttrs members;
    let
      names = attrNames members;

      mkStruct' =
        {
          total ? true,
          unknown ? false,
          verify ? null,
        }:
        assert isBool total;
        assert isBool unknown;
        assert verify != null -> isFunction verify;
        let
          # Turn member verifications into a list of verification functions with their verify functions
          # already looked up & with error contexts already computed.
          verifyAttrs = map (
            attr:
            let
              inherit (members.${attr}) verify;
            in
            if members.${attr}.__optional or (!total) then
              v:
              if !v ? ${attr} || verify v.${attr} == true then
                true
              else
                "in member '${attr}': ${verify v.${attr}}"
            else
              v:
              if v ? ${attr} then
                if verify v.${attr} == true then true else "in member '${attr}': ${verify v.${attr}}"
              else
                "missing member '${attr}'"
          ) names;

          allFuncs =
            verifyAttrs
            ++ optionalElem (!unknown) (
              v:
              if removeAttrs v names == { } then
                true
              else
                "keys [${joinKeys (attrNames (removeAttrs v names))}] are unrecognized, expected keys are [${joinKeys names}]"
            )
            ++ optionalElem (verify != null) verify;
        in
        self.new {
          inherit name;
          verify =
            v:
            if !isAttrs v then
              "in struct '${name}': ${typeError name v}"
            else if all (func: func v == true) allFuncs then
              true
            else
              # If an error was found, run the checks again to find the first error to return.
              foldl' (
                acc: func:
                if acc != true then
                  acc
                else if func v != true then
                  "in struct '${name}': ${func v}"
                else
                  acc
              ) true allFuncs;
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
    let
      name = "optionalAttr<${t.name}>";
      inherit (t) verify;
    in
    self.new {
      inherit name;
      verify = v: if verify v == true then true else "in ${name}: ${verify v}";
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
      verify = v: if elem v elems then true else "'${toPretty v}' is not a member of enum '${name}'";
    };

  /*
    tuple<elems...>
  */
  tuple =
    # List of tuple memeber types
    members:
    assert isList members;
    let
      name = "tuple<${concatStringsSep "," (map (t: t.name) members)}>";
      len = length members;
      funcs = map (t: t.verify) members;
      verifyValue =
        v: i:
        if i == len then
          true
        else if (elemAt funcs i) (elemAt v i) != true then
          ("in element ${toString i}: ${(elemAt funcs i) (elemAt v i)}")
        else
          verifyValue v (i + 1);
    in
    self.new {
      inherit name;
      verify =
        v:
        if !isList v then
          "in ${name}: ${typeError name v}"
        else if length v != len then
          "in ${name}: Expected tuple to have length ${toString len} but value '${toPretty v}' has length ${toString (length v)}"
        else if verifyValue v 0 == true then
          true
        else
          "in ${name}: ${verifyValue v 0}";
    };

  /*
    Create a wrapped type checked function.
  */
  defun =
    name: paramTypes: resultType:
    let
      verifyFuncs = map (type: type.verify) paramTypes;
      len = length paramTypes;
      verifyResult = resultType.verify;
      recurse =
        idx: acc:
        if idx != len then
          # more parameters need to be passed to the function
          let
            verify = elemAt verifyFuncs idx;
          in
          value:
          if verify value == true then
            recurse (idx + 1) (acc value)
          else
            throw "while calling '${name}': while checking argument ${toString idx}: ${verify value}"
        else
        # all parameters have been passed, check return value
        if verifyResult acc == true then
          acc
        else
          throw "while calling '${name}': while checking return type: ${verifyResult acc}";
    in
    recurse 0;
})
