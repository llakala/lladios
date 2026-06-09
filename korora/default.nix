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
  ``` nix
  { korora }:
  let
    t = korora.string;

    value = 1;

    # Error contains the string "Expected type 'string' but value '1' is of type 'int'"
    error = t.verify 1;

  in if error != null then throw error else value
  ```
  Errors are returned as a string.
  On success `null` is returned.

  - Checking (assertions)

  For convenience you can also check a value on-the-fly:
  ``` nix
  { korora }:
  let
    t = korora.string;

    value = 1;

    # Same error as previous example, but `check` throws.
    value = t.check value value;

  in value
  ```

  On error `check` throws. On success it returns the value that was passed in.

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
    genList
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
    split
    ;

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

  # Builtin primitive checkers return a bool for indicating errors but we return optional<string>
  wrapBoolVerify =
    name: verify: v:
    if verify v then null else typeError name v;

  fix =
    f:
    let
      x = f x;
    in
    x;

in
fix (self: {

  # Utility functions

  /*
    Declare a custom type using a bool function
  */
  typedef =
    # Name of the type as a string
    name:
    # Verification function returning a bool.
    verify:
    assert isFunction verify;
    {
      inherit name;
      verify = wrapBoolVerify name verify;
      check = v: v2: if verify v then v2 else throw (typeError name v);

      # The name of the type without polymorphic metadata
      __name = head (split "<" name);
    };

  /*
    Declare a custom type using an optional<string> function.
  */
  typedef' =
    # Name of the type as a string
    name:
    # Verification function returning null on success & a string with error message on error.
    verify:
    assert isFunction verify;
    {
      inherit name verify;
      check = v: v2: if verify v == null then v2 else throw (verify v);

      # The name of the type without polymorphic metadata
      __name = head (split "<" name);
    };

  /*
    Basic error function. Used internally, but also useful to throw errors in a
    custom type.
  */
  typeError = typeError;

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
        if verify v == null then recurse (i + 1) else verify v;
    in
    recurse 0;

  # Primitive types

  /*
    String
  */
  string = self.typedef "string" isString;

  /*
    Any
  */
  any = self.typedef' "any" (_: null);

  /*
    Never
  */
  never = self.typedef "never" (_: false);

  /*
    Int
  */
  int = self.typedef "int" isInt;

  /*
    Single precision floating point
  */
  float = self.typedef "float" isFloat;

  /*
    Either an int or a float
  */
  number = self.typedef "number" (v: isInt v || isFloat v);

  /*
    Bool
  */
  bool = self.typedef "bool" isBool;

  /*
    Null
  */
  null = self.typedef "null" isNull;

  /*
    Attribute with undefined attribute types
  */
  attrs = self.typedef "attrs" isAttrs;

  /*
    Attribute with undefined element types
  */
  list = self.typedef "list" isList;

  /*
    Function
  */
  function = self.typedef "function" isFunction;

  /*
    Path
  */
  path = self.typedef "path" isPath;

  /*
    Value that may not technically be a path, but has path-like properties
    Either an actual path `./foo`, a derivation, or a string
  */
  pathLike = self.typedef "pathLike" (v: isPath v || isDerivation v || isString v);

  /*
    Derivation
  */
  derivation = self.typedef "derivation" isDerivation;

  # Polymorphic types

  /*
    Type
  */
  type = self.typedef "type" (
    v: v ? name && isString v.name && v ? verify && isFunction v.verify
  );

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
    self.typedef' name (
      v:
      if v == null then
        null
      else if verify v == null then
        null
      else
        "in ${name}: ${verify v}"
    );

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
    self.typedef' name (
      list:
      if !isList list then
        typeError name list
      else if all (elem: verify elem == null) list then
        null
      else
        # If an error was found, run the checks again to find the first error to return.
        "in ${name} element: ${self.findFirstError verify list}"
    );

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
    self.typedef' name (
      attrs:
      if !isAttrs attrs then
        typeError name attrs
      else
      if all (value: verify value == null) (attrValues attrs) then
        null
      else
        self.findFirstError (
          key:
          if verify attrs.${key} == null then
            null
          else
            "in ${name} value: in attribute '${key}': ${verify attrs.${key}}"
        ) (attrNames attrs)
    );

  /*
    union<types...>
  */
  union =
    # Any of <t>
    types:
    assert isList types;
    let
      name = "union<${concatStringsSep "," (map (t: t.name) types)}>";
      funcs = map (t: t.verify) types;
    in
    self.typedef name (v: any (func: func v == null) funcs);

  /*
    intersection<types...>
  */
  intersection =
    # All of <t>
    types:
    assert isList types;
    let
      name = "intersection<${concatStringsSep "," (map (t: t.name) types)}>";
      funcs = map (t: t.verify) types;
    in
    self.typedef name (v: all (func: func v == null) funcs);

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
  rename = name: type: self.typedef' name type.verify;

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
              if !v ? ${attr} || verify v.${attr} == null then
                null
              else
                "in member '${attr}': ${verify v.${attr}}"
            else
              v:
              if v ? ${attr} then
                if verify v.${attr} == null then null else "in member '${attr}': ${verify v.${attr}}"
              else
                "missing member '${attr}'"
          ) names;

          allFuncs =
            verifyAttrs
            ++ optionalElem (!unknown) (
              v:
              if removeAttrs v names == { } then
                null
              else
                "keys [${joinKeys (attrNames (removeAttrs v names))}] are unrecognized, expected keys are [${joinKeys names}]"
            )
            ++ optionalElem (verify != null) verify;
        in
        self.typedef' name (
          v:
          if !isAttrs v then
            "in struct '${name}': ${typeError name v}"
          else if all (func: func v == null) allFuncs then
            null
          else
            # If an error was found, run the checks again to find the first error to return.
            foldl' (
              acc: func:
              if acc != null then
                acc
              else if func v != null then
                "in struct '${name}': ${func v}"
              else
                acc
            ) null allFuncs
        )
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
    self.typedef' name (v: if verify v == null then null else "in ${name}: ${verify v}") // makeOptional;

  /*
    enum<name, elems...>
  */
  enum =
    # Name of enum type as a string
    name:
    # List of allowable enum members
    elems:
    assert isList elems;
    self.typedef' name (
      v: if elem v elems then null else "'${toPretty v}' is not a member of enum '${name}'"
    );

  /*
    tuple<elems...>
  */
  tuple =
    # List of tuple memeber types
    members:
    assert isList members;
    let
      name = "tuple<${concatStringsSep ", " (map (t: t.name) members)}>";
      len = length members;
      funcs = map (t: t.verify) members;
      verifyValue =
        v: i:
        if i == len then
          null
        else if (elemAt funcs i) (elemAt v i) != null then
          ("in element ${toString i}: ${(elemAt funcs i) (elemAt v i)}")
        else
          verifyValue v (i + 1);
    in
    self.typedef' name (
      v:
      if !isList v then
        "in ${name}: ${typeError name v}"
      else if length v != len then
        "in ${name}: Expected tuple to have length ${toString len} but value '${toPretty v}' has length ${toString (length v)}"
      else if verifyValue v 0 == null then
        null
      else
        "in ${name}: ${verifyValue v 0}"
    );

  /*
    Create a wrapped type checked function.
  */
  defun =
    name: args: T: f:
    let
      errorPrefix = "while calling '${name}'";
    in
    foldl'
      (
        fun: idx:
        let
          type = elemAt args idx;
        in
        value:
        if type.verify value != null then
          throw "${errorPrefix}: while checking argument ${toString idx}: ${type.verify value}"
        else
          fun value
      )
      (
        arg:
        let
          value = f arg;
          err = T.verify value;
        in
        if err != null then throw "${errorPrefix}: while checking return type: ${err}" else value
      )
      (genList (i: i) (length args));
})
