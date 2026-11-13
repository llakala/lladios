/*
  A tiny & fast composable type system for Nix, in Nix.

  Named after the [little penguin](https://www.doc.govt.nz/nature/native-animals/birds/birds-a-z/penguins/little-penguin-korora/).

  # Features

  - Types
    - Primitive types (`string`, `int`, etc)
    - Polymorphic types (`union`, `attrsOf`, etc)
    - Struct types

  # Usage

  ## Defining types

  Korora exposes a set of basic types and several polymorphic types. This API
  should be powerful enough for most purposes.

  ```nix
  { types, ... }:
  {
    t1 = types.int;
    t2 = types.attrsOf types.int;
    t3 = types.either (types.attrsOf types.int) (types.listOf types.bool);
    t4 = types.struct "someStructName" {
      a = types.path;
      b = types.optionalAttr types.bool;
      c = types.listOf (types.nullOr types.string);
    };
    t5 = types.enum "someEnumName" [
      "a"
      null
      28
      [ 1 8 15 ]
    ];
  }
  ```

  ## Creating custom types

  If your type cannot be expressed with the set of base types, a custom type can
  be defined using `types.new`.

  ```nix
  { types, ... }:
  {
    t1 = types.new {
      name = "positiveInteger";
      # verify is called with some value, and returns whether the typecheck
      # passed
      verify = v: isInt v && v >= 0;
      apply = null; # return the input value upon passing
    };
    t2 = types.new {
      name = "nonEmptyString";
      verify = v: isString v && length v != 0;
      apply = null;
      explain =
        v:
        # return a custom error message when the typecheck fails
        if !isString v then
          "value was a(n) ${typeOf v} instead of a string"
        else
          "value was an empty string";
    };
    t3 = types.new {
      # if the value is a list of integers, pass the typecheck and return the
      # integers summed together
      name = "intMerger";
      verify = v: isList v && all isInt v;
      # return a new value when v passes the `verify` function
      apply = v: foldl' (acc: v: acc + v) 0 list;
    };
  }
  ```

  See also the documentation on `types.new`.

  # Calling types yourself

  Korora is primarily intended for usage within Adios, where typechecks will be
  automatically applied. However, Korora can be used as a generic typing library
  for Nix in other contexts. To do this, one should be familar with the API
  exposed by a type.

  ## Checking a value (throws on error)

  Korora types expose a `check` function. This is the attribute used by Adios,
  and is likely to fit most usecases.

  ```nix
  { types, ... }:
  let
    t = types.string;
    value = 1;
  in
  t.check value
  ```

  On success, `check` returns the input value `v`. If the type had apply
  semantics, it instead returns the result of `apply v`.

  On failure, `check` throws an error message, using the type's `explain`
  function if it was defined.

  ## Inspecting (doesn't throw on error)

  For cases where it doesn't make sense to throw (such as testing), the
  `inspect` attribute can be used to determine whether a typecheck passes. This
  is currently an implementation detail for testing Korora, and it may change in
  the future.

  ```nix
  { types, ... }:
  let
    t = types.string;
    value = 1;
    error = t.inspect value;
  in
  if error == null then
    # handle success case
  else
    # use the string error message however you wish
  ```

  On success, `inspect` returns null. On failure, it returns an error message as a string.

  ## Other attributes

  Types also expose the attributes used to define them - `name`, `verify`, `explain`,
  and `apply`. These are useful when creating a custom polymorphic type.

  ```nix
  singleton =
    t:
    let
      name = "singleton<${t.name}>";
      # for performance, only lookup the attributes once
      inherit (t) verify apply explain;
    in
    types.new {
      inherit name;
      verify = list: isList list && length list == 1 && verify (head list);
      # call the apply function if it's defined. if not, set `apply = null` to
      # prevent any overhead
      apply = if apply == null then null else v: apply (head v);
      explain =
        v:
        if !isList v then
          "in type '${name}': value was expected to be a list, but was a(n) '${typeOf v}'"
        else if length v != 1 then
          "in type '${name}': list was of length '${length v}', but was expected to be of length 1"
        else
          "in type '${name}': in element: '${explain (head v)}'";
    };
  ```

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
    catAttrs
    concatStringsSep
    elem
    elemAt
    filter
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
    mapAttrs
    partition
    seq
    trace
    ;
  warn = builtins.warn or builtins.trace;

  concatCommas = concatStringsSep ",";
  getNames = catAttrs "name";
  joinKeys = list: concatCommas (map (e: "'${e}'") list);
  joinTypes = list: concatCommas (getNames list);

  toPretty = import ./toPretty.nix { indent = "    "; };

  notOfType =
    # name of the expected type
    name:
    # value that failed the type check
    v:
    "value '${toPretty v}' is not of type '${name}'";

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

  # Find the first element in the list where the given function returns a string
  # (representing an error).
  # If the validate function passes for all elements, returns null
  validateAll =
    # returns null/string depending on whether typecheck passed
    validate:
    # list of elemenets to attempt validation on
    list:
    let
      len = length list;
      recurse =
        i:
        let
          result = validate (elemAt list i);
        in
        if i == len then
          null
        else if result == null then
          recurse (i + 1)
        else
          result;
    in
    recurse 0;

  # Find the first function that fails on the given value.
  explainFirstFailingFunction =
    # each element returns true/false
    verifiers:
    # each element contains a custom error message
    explanations:
    # the value to be checked
    v:
    let
      recurse = i: if (elemAt verifiers i) v then recurse (i + 1) else elemAt explanations i;
    in
    recurse 0;

  typedefWarning = warn ''
    At least one of your Adios modules used `types.typedef` or `types.typedef'`.
    These functions have been deprecated in favor of `types.new`.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#new-typedef-function'' null;
  nullWarning = warn ''
    At least one of your Adios typechecks returned null.
    On success, typechecks should now return a string.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#new-typedef-function'' null;
  noApplyWarning = trace ''
    At least one of your Adios types (defined via `types.new` didn't specify an `apply` attribute.
    'apply' allows types to return a new value upon passing. For types without apply semantics, it should be set to null.

    See the lladios changelog for more info:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#apply-semantics'' null;
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
      # Function to "apply" the type when it passes. Only necessary when a type
      # has apply semantics. For basic types, set this to null.
      apply ? seq noApplyWarning (warn "no 'apply' attribute in type '${name}'" null),
      # Function to generate an error message when the verify function fails.
      explain ? notOfType name,
    }:
    {
      inherit
        name
        verify
        explain
        apply
        ;
      inspect =
        if apply == null then
          v: if verify v then null else explain v
        else
          v: if verify v then seq (apply v) null else explain v;
      check =
        if apply == null then
          v:
          if verify v == true then
            v
          else if verify v == null then
            seq nullWarning v
          else
            throw (explain v)
        else
          v:
          if verify v == true then
            apply v
          else if verify v == null then
            seq nullWarning v
          else
            throw (explain v);
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
  typeError =
    # value that failed the type check
    v: "value '${toPretty v}' failed the type check";

  /*
    Used internally, but also useful in documentation generation.
  */
  toPretty = import ./toPretty.nix;

  # Primitive types

  /*
    String
  */
  string = self.new {
    name = "string";
    verify = isString;
    apply = null;
  };

  /*
    Any
  */
  any = self.new {
    name = "any";
    verify = _: true;
    apply = null;
  };

  /*
    Never
  */
  never = self.new {
    name = "never";
    verify = _: false;
    apply = null;
  };

  /*
    Int
  */
  int = self.new {
    name = "int";
    verify = isInt;
    apply = null;
  };

  /*
    Single precision floating point
  */
  float = self.new {
    name = "float";
    verify = isFloat;
    apply = null;
  };

  /*
    Either an int or a float
  */
  number = self.new {
    name = "number";
    verify = v: isInt v || isFloat v;
    apply = null;
  };

  /*
    Bool
  */
  bool = self.new {
    name = "bool";
    verify = isBool;
    apply = null;
  };

  /*
    Null
  */
  null = self.new {
    name = "null";
    verify = isNull;
    apply = null;
  };

  /*
    Attribute with undefined attribute types
  */
  attrs = self.new {
    name = "attrs";
    verify = isAttrs;
    apply = null;
  };

  /*
    Attribute with undefined element types
  */
  list = self.new {
    name = "list";
    verify = isList;
    apply = null;
  };

  /*
    Function
  */
  function = self.new {
    name = "function";
    verify = isFunction;
    apply = null;
  };

  /*
    Path
  */
  path = self.new {
    name = "path";
    verify = isPath;
    apply = null;
  };

  /*
    Value that may not technically be a path, but has path-like properties
    Either an actual path `./foo`, a derivation, or a string
  */
  pathLike = self.new {
    name = "pathLike";
    verify = v: isPath v || v.type or null == "derivation" || isString v;
    apply = null;
  };

  /*
    Derivation
  */
  derivation = self.new {
    name = "derivation";
    verify = v: v.type or null == "derivation";
    apply = null;
  };

  # Polymorphic types

  /*
    Type
  */
  type = self.new {
    name = "type";
    verify = v: v ? name && isString v.name && v ? verify && isFunction v.verify;
    apply = null;
  };

  optional = warn "Adios type 'optional<t>' has been renamed to 'nullOr<t>'" self.nullOr;

  /*
    nullOr<t>
  */
  nullOr =
    # Null or t
    t:
    let
      inherit (t) verify apply;
    in
    self.new {
      name = "nullOr<${t.name}>";
      verify = v: v == null || verify v;
      # `t` could accept null values and provide apply semantics - so must
      # reverify
      apply = if apply == null then null else v: if verify v then apply v else v;
    };

  /*
    listOf<t>
  */
  listOf =
    # Element type
    t:
    let
      name = "listOf<${t.name}>";
      verifyAll = all t.verify;
      apply = t.apply;
    in
    self.new {
      inherit name;
      verify = list: isList list && verifyAll list;
      apply = if apply == null then null else map apply;
      explain =
        list:
        "in type '${name}': "
        + (
          if !isList list then
            notOfType "list" list
          else
            "in element: ${explainFirstFailingValue t.verify t.explain list}"
        );
    };

  /*
    attrsOf<t>
  */
  attrsOf =
    # Attribute value type
    t:
    let
      name = "attrsOf<${t.name}>";
      verifyAll = all t.verify;
      apply = t.apply;
    in
    self.new {
      inherit name;
      verify = attrs: isAttrs attrs && verifyAll (attrValues attrs);
      apply = if apply == null then null else mapAttrs (_: apply);
      explain =
        attrs:
        "in type '${name}': "
        + (
          if !isAttrs attrs then
            notOfType "attrs" attrs
          else
            explainFirstFailingValue (key: t.verify attrs.${key}) (
              key: "in attribute '${key}': ${t.explain attrs.${key}}"
            ) (attrNames attrs)
        );
    };

  /*
    union<types...>
  */
  union =
    # Any of <t>
    types:
    assert isList types;
    let
      name = "union<${joinTypes types}>";
      partitioned = partition (t: t.apply == null) types;
      verifiers = map (t: t.verify) (
        # To prevent types with apply semantics from accepting early and
        # throwing later, a subtype with apply semantics must be checked last
        if partitioned.wrong == [ ] then types else partitioned.right ++ partitioned.wrong
      );
    in
    self.new {
      inherit name;
      verify =
        # Putting the error down here makes the type shape-stable, and helps to
        # prevent some infinite recursion errors
        if length partitioned.wrong > 1 then
          throw ''
            type '${name}' specified multiple types with apply semantics.

            These types were: <${joinTypes partitioned.wrong}>

            'types.either' only allows one type to provide apply semantics. This
            prevents an edge case where a type provides a lax verification function,
            and then throws in the apply stage.

            If you're sure that this union is safe, define a custom type that
            applies the first type to pass verification.''
        else
          v: any (verifier: verifier v) verifiers;
      # TODO: custom error message
      apply =
        if partitioned.wrong == [ ] then
          null
        else
          # Apply the applier if necessary. This only re-verifies one type,
          # rather than all of them.
          let
            inherit (head partitioned.wrong) verify apply;
          in
          v: if verify v then apply v else v;
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
      name = "either<${t1.name},${t2.name}>";
      verify1 = t1.verify;
      verify2 = t2.verify;
      apply1 = t1.apply;
      apply2 = t2.apply;
    in
    self.new {
      inherit name;
      verify =
        if apply1 != null && apply2 != null then
          throw ''
            type '${name}' had both types provide apply semantics.

            'types.either' only allows one type to provide apply semantics. This
            prevents an edge case where a type provides a lax verification function,
            and then throws in the apply stage.

            If you're sure that this union is safe, define a custom type that
            applies the first type to pass verification.''
        else if apply1 == null then
          # Verify the type _without_ apply semantics first, to prevent an early
          # accept that throws later
          v: verify1 v || verify2 v
        else
          v: verify2 v || verify1 v;
      apply =
        if apply1 == apply2 then
          null
        else if apply1 == null then
          v: if verify1 v then v else apply2 v
        else
          v: if verify2 v then v else apply1 v;
    };

  # intersection<types...>
  intersection =
    # All of <t>
    types:
    assert isList types;
    let
      verifiers = map (t: t.verify) types;
      appliers = filter (t: t.apply != null) types;
      name = "intersection<${joinTypes types}>";
    in
    self.new {
      inherit name;
      verify =
        if length appliers > 1 then
          throw ''
            type '${name}' tried to intersect multiple types with 'apply' semantics.

            These types were: <${joinTypes appliers}>

            To prevent unintuitive behavior, 'types.intersection' only allows a single
            type to have apply semantics. This preserves numerous properties, like order
            not mattering.

            If you do want multiple application steps to be performed, write a custom type
            that performs them in the desired order.''
        else
          v: all (verifier: verifier v) verifiers;
      # TODO: custom explain message
      apply = if appliers == [ ] then null else (head appliers).apply;
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
      apply1 = t1.apply;
      apply2 = t2.apply;
      name = "all<${t1.name},${t2.name}>";
    in
    self.new {
      inherit name;
      verify =
        if apply1 != null && apply2 != null then
          throw ''
            type '${name}' had both of its types specify 'apply' semantics.

            To prevent unintuitive behavior, 'types.both' only allows a single type to
            have apply semantics. This preserves numerous properties, like order not
            mattering.

            If you do want both application steps to be performed, write a custom type
            that applies one after the other in the desired order.''
        else
          v: verify1 v && verify2 v;
      apply =
        if apply1 == apply2 then
          null
        else if apply1 == null then
          apply1
        else
          apply2;
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

    Note that this adds a slight amount of overhead (a single function call) to
    the type, by always including an `apply` function. This is done to prevent
    infinite recursion.
  */
  rename =
    name: type:
    let
      inherit (type) apply;
    in
    # TODO: properly handle optionalAttr
    self.new {
      inherit name;
      inherit (type) verify explain;
      apply = v: if apply == null then v else apply v;
    };

  /*
    struct<name, members...>

    #### Example
    ```nix
    korora.struct "myStruct" {
      foo = types.string;
      bar = types.int;
      baz = types.optionalAttr types.bool;
    }
    ```

    ### Features

    #### Totality

    By default, all attribute names must be present in a struct (modulo
    `optionalAttr`). It is possible to override this by specifying _totality_.

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

    #### Tips

    Setting `total = false` is equivalent to using `optionalAttr` for every
    type. However, the algorithm that's used is different.

    When `total = true` (the default), structs iterate through every member,
    including optional members. If a member wasn't specified, but was optional,
    they simply skip the current iteration.

    When `total = false`, structs instead iterate through every attribute that's
    actually specified. This improves performance when most of the attributes
    are specified rarely.

    If your struct requires some attributes to be specified, but most optional
    attributes are never set, it may be worth it to set `total = false`,
    and check for the required elements yourself in a custom `verify` function.

    For example:
    ```nix
    (types.struct "testStruct3" {
      requiredAttribute = types.int;
      optionalA = types.int;
      optionalB = types.string;
      optionalC = types.functoin;
    }).override {
      total = false;
      verify = v: v ? requiredAttribute;
    }
    ```
  */
  struct =
    let
      verifyTotalStruct =
        types: total: unknown: verify:
        let
          names = attrNames types;
          partioned = partition (name: types.${name}.__optional or false) names;
          verifiers =
            (
              if unknown then
                [ ]
              else if partioned.right == [ ] then
                [ (v: attrNames v == names) ]
              else
                [ (v: removeAttrs v names == { }) ]
            )
            ++ map (
              name:
              let
                verify = types.${name}.verify;
              in
              # optional types don't have to be specified
              v: !v ? ${name} || verify v.${name}
            ) partioned.right
            ++ map (
              name:
              let
                verify = types.${name}.verify;
              in
              if unknown then
                v: v ? ${name} && verify v.${name}
              else
                # when unknown = false, the first verifier guarantees that all
                # specified names are unknown, so no need to use ? and check it
                # again
                v: verify v.${name}
            ) partioned.wrong
            ++ (if verify == null then [ ] else [ verify ]);
        in
        v: isAttrs v && all (verifier: verifier v) verifiers;
      verifyNonTotalStruct =
        types: total: unknown: verify:
        let
          noCustomVerify = verify == null;
          verifiers = mapAttrs (_: type: type.verify) types;
        in
        if unknown then
          v:
          isAttrs v
          # if attribute is a member, it passes
          && all (name: !verifiers ? ${name} || verifiers.${name} v.${name}) (attrNames v)
          # custom verifier passes
          && (noCustomVerify || verify v)
        else
          v:
          isAttrs v
          # all attributes are members and pass
          && all (name: verifiers.${name} or (_: false) v.${name}) (attrNames v)
          # custom verifier passes
          && (noCustomVerify || verify v);
    in
    # Name of struct type as a string
    name:
    # Attribute set of type definitions.
    types:
    let
      mkStruct' =
        {
          total ? true,
          unknown ? false,
          verify ? null,
          explain ? null,
        }:
        self.new {
          name = "struct<${name}>";
          verify = (if total then verifyTotalStruct else verifyNonTotalStruct) types total unknown verify;
          apply =
            if all (t: t.apply == null) (attrValues types) then
              null
            else
              let
                appliers = mapAttrs (_: type: type.apply) types;
              in
              mapAttrs (name: if appliers.${name} or null == null then v: v else appliers.${name});
          explain =
            v:
            let
              names = attrNames types;
              explanation = validateAll (
                name:
                if !v ? ${name} then
                  if !total || (types.${name}.__optional or false) then null else "missing member '${name}'"
                else if !types.${name}.verify v.${name} then
                  "in member '${name}': ${types.${name}.explain v.${name}}"
                else
                  null
              ) names;
            in
            "in struct '${name}': "
            + (
              if !isAttrs v then
                notOfType "attrs" v
              else if explanation != null then
                explanation
              else if !unknown && (removeAttrs v names != { }) then
                "keys [${joinKeys (attrNames (removeAttrs v names))}] are unrecognized, expected keys are [${joinKeys names}]"
              else if explain == null then
                "failed to match custom verification function"
              else
                explain v
            );
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
    t:
    self.new {
      name = "optionalAttr<${t.name}>";
      inherit (t) verify apply;
    }
    // {
      __optional = true;
      # propagate original error, optionalAttr is implementation detail
      explain = t.explain;
    };

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
      apply = null;
      explain = v: "in type '${name}': '${toPretty v}' is not a member of the enum";
    };

  /*
    tuple<elems...>
  */
  tuple =
    # List of tuple member types
    types:
    assert isList types;
    let
      name = "tuple<${joinTypes types}>";
      len = length types;
      verifiers = genList (
        i:
        let
          verify = (elemAt types i).verify;
        in
        v: verify (elemAt v i)
      ) len;
    in
    self.new {
      inherit name;
      verify = v: isList v && length v == len && all (verifier: verifier v) verifiers;
      apply =
        if all (t: t.apply == null) types then
          null
        else
          v:
          genList (
            i:
            let
              apply = (elemAt types i).apply;
            in
            if apply == null then elemAt v i else apply (elemAt v i)
          ) len;
      explain =
        tuple:
        if !isList tuple then
          "in type '${name}': " + notOfType "list" tuple
        else if length tuple != len then
          "in type '${name}': expected tuple of length ${toString len} but value '${toPretty tuple}' has length ${toString (length tuple)}"
        else
          let
            explainers = genList (
              i:
              let
                type = elemAt types i;
                tupleElem = elemAt tuple i;
              in
              "in element ${toString i} of type '${name}': ${type.explain tupleElem}"
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
      len = length paramTypes;
      recurse =
        i: acc:
        if i != len then
          # more parameters need to be passed to the function
          let
            type = elemAt paramTypes i;
          in
          if type.apply != null then
            throw "types.defun doesn't support apply semantics yet, but they were used in param type '${type.name}"
          else
            value:
            if type.verify value then
              recurse (i + 1) (acc value)
            else
              throw "in argument ${toString i}: ${type.explain value}"
        else
        # all parameters have been passed, check return value
        if resultType.apply != null then
          throw "types.defun doesn't support apply semantics yet, but they were used in result type '${resultType.name}"
        else if resultType.verify acc then
          acc
        else
          throw "in return type: ${resultType.explain acc}";
    in
    recurse 0;
})
