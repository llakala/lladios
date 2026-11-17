# run `nix-unit korora/tests.nix` to see if the tests pass
{
  sources ? import ../npins,
  lib ? import (sources.nixpkgs + "/lib"),
}:

let
  inherit (lib) toUpper substring stringLength;

  types = import ./default.nix;

  capitalise = s: toUpper (substring 0 1 s) + (substring 1 (stringLength s) s);

  # TODO: shrink this as much as possible. Ideally everything has tests.
  untestedTypes = {
    typeError = true;
    toPretty = true;
    optional = true;
    # FIXME: one of the commits touches this, need to write the tests
    typedef = true;
    typedef' = true;
    # TODO: write tests for the pre-apply version of this especially and test parity
    # TODO: write tests for post-apply scheme
    new = true;
  };

  addCoverage =
    public: tests:
    (
      assert !tests ? coverage;
      tests
      // {
        coverage =
          let
            coverageFor =
              base:
              lib.mapAttrs' (
                n: _v: {
                  name = "test" + (capitalise n);
                  value = {
                    expr = base ? ${n} || untestedTypes ? ${n};
                    expected = true;
                  };
                }
              );
          in
          (coverageFor tests public)
          // {
            lazy = coverageFor tests.lazy public.lazy;
            unsafe = coverageFor tests.unsafe public.unsafe;
          };
      }
    );

  # For testing multi-apply semantics.
  incrementer = types.new {
    name = "incrementer";
    verify = builtins.isInt;
    apply = v: v + 1;
  };
  doubler = types.new {
    name = "doubler";
    verify = builtins.isInt;
    apply = v: v * 2;
  };
in
lib.fix (
  _self:
  addCoverage types {
    string = {
      testInvalid = {
        expr = types.string.inspect 1;
        expected = "value '1' is not of type 'string'";
      };

      testValid = {
        expr = types.string.inspect "Hello";
        expected = null;
      };
    };

    function = {
      testInvalid = {
        expr = types.function.inspect 1;
        expected = "value '1' is not of type 'function'";
      };

      testValid = {
        expr = types.function.inspect (_: null);
        expected = null;
      };
    };

    path = {
      testInvalid = {
        expr = types.path.inspect 1;
        expected = "value '1' is not of type 'path'";
      };

      testValid = {
        expr = types.path.inspect ./.;
        expected = null;
      };
    };

    pathLike = {
      testInvalid = {
        expr = types.pathLike.inspect 1;
        expected = "value '1' is not of type 'pathLike'";
      };

      testPath = {
        expr = types.pathLike.inspect ./.;
        expected = null;
      };
      # I'd like to add testDerivation, but the tests dont like needing
      # <nixpkgs>
      testString = {
        expr = types.pathLike.inspect "example string";
        expected = null;
      };
    };

    derivation = {
      testInvalid = {
        expr = types.derivation.inspect { };
        expected = "value '{ }' is not of type 'derivation'";
      };

      testValid = {
        expr = types.derivation.inspect (
          builtins.derivation {
            name = "test";
            builder = ":";
            system = "fake";
          }
        );
        expected = null;
      };
    };

    any = {
      testValid = {
        expr = types.any.inspect (throw "NO U"); # Note: Value not checked
        expected = null;
      };
    };

    never = {
      testInvalid = {
        expr = types.never.inspect 1234;
        expected = "value '1234' is not of type 'never'";
      };
    };

    int = {
      testInvalid = {
        expr = types.int.inspect "x";
        expected = "value '\"x\"' is not of type 'int'";
      };

      testValid = {
        expr = types.int.inspect 1;
        expected = null;
      };
    };

    float = {
      testInvalid = {
        expr = types.float.inspect "x";
        expected = "value '\"x\"' is not of type 'float'";
      };

      testValid = {
        expr = types.float.inspect 1.0;
        expected = null;
      };
    };

    number = {
      testInvalid = {
        expr = types.number.inspect "x";
        expected = "value '\"x\"' is not of type 'number'";
      };

      testValidInt = {
        expr = types.number.inspect 1;
        expected = null;
      };

      testValidFloat = {
        expr = types.number.inspect 1.0;
        expected = null;
      };
    };

    bool = {
      testInvalid = {
        expr = types.bool.inspect "x";
        expected = "value '\"x\"' is not of type 'bool'";
      };

      testValid = {
        expr = types.bool.inspect true;
        expected = null;
      };
    };

    null = {
      testInvalid = {
        expr = types.null.inspect "x";
        expected = "value '\"x\"' is not of type 'null'";
      };

      testValid = {
        expr = types.null.inspect null;
        expected = null;
      };
    };

    attrs = {
      testInvalid = {
        expr = types.attrs.inspect "x";
        expected = "value '\"x\"' is not of type 'attrs'";
      };

      testValid = {
        expr = types.attrs.inspect { };
        expected = null;
      };
    };

    list = {
      testInvalid = {
        expr = types.list.inspect "x";
        expected = "value '\"x\"' is not of type 'list'";
      };

      testValid = {
        expr = types.list.inspect [ ];
        expected = null;
      };
    };

    listOf =
      let
        testListOf = types.listOf types.string;
      in
      {
        testValid = {
          expr = testListOf.inspect [ "hello" ];
          expected = null;
        };

        testInvalidElem = {
          expr = testListOf.inspect [ 1 ];
          expected = "in type 'listOf<string>': in element: value '1' is not of type 'string'";
        };

        testInvalidType = {
          expr = testListOf.inspect 1;
          expected = "in type 'listOf<string>': value '1' is not of type 'list'";
        };
      };

    attrsOf =
      let
        testAttrsOf = types.attrsOf types.string;
      in
      {
        testValid = {
          expr = testAttrsOf.inspect {
            x = "hello";
          };
          expected = null;
        };

        testInvalidElem = {
          expr = testAttrsOf.inspect {
            x = 1;
          };
          expected = "in type 'attrsOf<string>': in attribute 'x': value '1' is not of type 'string'";
        };

        testInvalidType = {
          expr = testAttrsOf.inspect 1;
          expected = "in type 'attrsOf<string>': value '1' is not of type 'attrs'";
        };
      };

    union =
      let
        testUnion = types.union [
          types.string
          types.bool
        ];

        typeWithApply = types.new {
          name = "1";
          verify = _: true;
          apply = v: v;
        };
        unsafeTypes = types.union [
          typeWithApply
          typeWithApply
        ];
      in
      {
        testFirstValid = {
          expr = testUnion.inspect "hello";
          expected = null;
        };

        testSecondValid = {
          expr = testUnion.inspect false;
          expected = null;
        };

        testInvalid = {
          expr = testUnion.inspect 1;
          expected = "in type 'union<string,bool>': '1' is not a member of the union";
        };

        testSafeConstruction = {
          expr = unsafeTypes.inspect null;
          expectedError.type = "ThrownError";
        };
      };

    either =
      let
        testEither = types.either types.string types.bool;

        typeWithApply = types.new {
          name = "1";
          verify = _: true;
          apply = v: v;
        };
        unsafeTypes = types.either typeWithApply typeWithApply;
      in
      {
        testFirst = {
          expr = testEither.inspect "hello";
          expected = null;
        };
        testSecond = {
          expr = testEither.inspect false;
          expected = null;
        };

        testInvalid = {
          expr = testEither.inspect 1;
          expected = "value '1' is not of type 'either<string,bool>'";
        };

        testSafeConstruction = {
          expr = unsafeTypes.inspect null;
          expectedError.type = "ThrownError";
        };
      };

    intersection =
      let
        struct1 = types.struct "1" {
          a = types.number;
        };

        struct2 = types.struct "2" {
          a = types.int;
        };

        testIntersection = types.intersection [
          struct1
          struct2
        ];

        typeWithApply = types.new {
          name = "1";
          verify = _: true;
          apply = v: v;
        };
        unsafeTypes = types.intersection [
          typeWithApply
          typeWithApply
        ];
      in
      {
        testValid = {
          expr = testIntersection.inspect {
            a = 1;
          };
          expected = null;
        };

        testInvalid = {
          expr = testIntersection.inspect 1;
          expected = "value '1' is not of type 'intersection<struct<1>,struct<2>>'";
        };

        testSafeConstruction = {
          expr = unsafeTypes.inspect null;
          expectedError.type = "ThrownError";
        };
      };

    both =
      let
        testBoth = types.both types.int (
          types.new {
            name = "positive";
            verify = v: v >= 0;
            apply = null;
          }
        );

        typeWithApply = types.new {
          name = "1";
          verify = _: true;
          apply = v: v;
        };
        unsafeTypes = types.both typeWithApply typeWithApply;
      in
      {
        testValid = {
          expr = testBoth.inspect 5;
          expected = null;
        };

        testInvalid1 = {
          expr = testBoth.inspect (-1);
          expected = "value '-1' is not of type 'all<int,positive>'";
        };
        testInvalid2 = {
          expr = testBoth.inspect "no";
          expected = "value '\"no\"' is not of type 'all<int,positive>'";
        };

        testSafeConstruction = {
          expr = unsafeTypes.inspect null;
          expectedError.type = "ThrownError";
        };
      };

    type = {
      testValid = {
        expr = types.type.inspect types.string;
        expected = null;
      };

      testInvalid = {
        expr = types.type.inspect { };
        expected = "value '{ }' is not of type 'type'";
      };
    };

    nullOr =
      let
        testOption = types.nullOr types.string;
        testStruct = types.struct "test-struct" {
          foo = testOption;
        };
      in
      {
        testValidString = {
          expr = testOption.inspect "hello";
          expected = null;
        };

        testNull = {
          expr = testOption.inspect null;
          expected = null;
        };

        testInvalid = {
          expr = testOption.inspect 3;
          expected = "value '3' is not of type 'nullOr<string>'";
        };
        testInvalidWithinStruct = {
          expr = testStruct.inspect { foo = 5; };
          expected = "in struct 'test-struct': in member 'foo': value '5' is not of type 'nullOr<string>'";
        };
      };

    struct =
      let
        testStruct = types.struct "test1" {
          foo = types.string;
        };

        testStructCustomVerify =
          (types.struct "test2" {
            x = types.int;
            y = types.int;
          }).override
            {
              verify = v: v.x + v.y != 2;
              explain = v: "VERBOTEN";
            };

        testStructCustomVerifyNoExplain = testStructCustomVerify.override {
          verify = v: v.x + v.y != 2;
        };

        testStructNonTotal = testStruct.override { total = false; };
        testStructUnknown = testStruct.override { unknown = true; };
        testStructNonTotalUnknown = testStructCustomVerify.override {
          total = false;
          unknown = true;
        };
      in
      {
        testValid = {
          expr = testStruct.inspect {
            foo = "bar";
          };
          expected = null;
        };

        testUnknownDisallowed = {
          expr = testStruct.inspect {
            foo = "bar";
            bar = "foo";
          };
          expected = "in struct 'test1': keys ['bar'] are unrecognized, expected keys are ['foo']";
        };

        testMissingAttr = {
          expr = testStruct.inspect { };
          expected = "in struct 'test1': missing member 'foo'";
        };

        testNonTotalAllowed = {
          expr = testStructNonTotal.inspect { };
          expected = null;
        };

        testExtraInvariantCheck = {
          expr = testStructCustomVerify.inspect {
            x = 1;
            y = 1;
          };
          expected = "in struct 'test2': VERBOTEN";
        };

        testExtraInvariantMissingExplainCheck = {
          expr = testStructCustomVerifyNoExplain.inspect {
            x = 1;
            y = 1;
          };
          expected = "in struct 'test2': failed to match custom verification function";
        };

        testUnknownAllowed = {
          expr = testStructUnknown.inspect {
            foo = "bar";
            bar = "foo";
          };
          expected = null;
        };

        testUnknownMissingAttribute = {
          expr = testStructUnknown.inspect {
            bar = "foo";
          };
          expected = "in struct 'test1': missing member 'foo'";
        };

        testUnknownNonTotal = {
          expr = testStructNonTotalUnknown.inspect {
            bar = null;
          };
          expected = null;
        };

        testInvalidType = {
          expr = testStruct.inspect "bar";
          expected = "in struct 'test1': value '\"bar\"' is not of type 'attrs'";
        };

        testInvalidMember = {
          expr = testStruct.inspect {
            foo = 1;
          };
          expected = "in struct 'test1': in member 'foo': value '1' is not of type 'string'";
        };
      };

    optionalAttr =
      let
        testStruct = types.struct "testOptionalAttr" {
          foo = types.string;
          optionalFoo = types.optionalAttr types.string;
        };

      in
      {
        testWithOptional = {
          expr = testStruct.inspect {
            foo = "hello";
            optionalFoo = "goodbye";
          };
          expected = null;
        };

        testWithoutOptional = {
          expr = testStruct.inspect {
            foo = "hello";
          };
          expected = null;
        };

        testWithInvalidOptional = {
          expr = testStruct.inspect {
            foo = "hello";
            optionalFoo = 1234;
          };
          expected = "in struct 'testOptionalAttr': in member 'optionalFoo': value '1234' is not of type 'string'";
        };
      };

    enum =
      let
        testEnum = types.enum "testEnum" [
          "A"
          "B"
          "C"
        ];
      in
      {
        testHasElem = {
          expr = testEnum.inspect "B";
          expected = null;
        };

        testNotHasElem = {
          expr = testEnum.inspect "nope";
          expected = "in type 'testEnum': '\"nope\"' is not a member of the enum";
        };
      };

    rename = {
      testRename = {
        expr =
          let
            t = types.rename "florp" types.string;
          in
          {
            inherit (t) name;
            isFunction = builtins.isFunction t.inspect;
          };
        expected = {
          name = "florp";
          isFunction = true;
        };
      };
    };

    tuple =
      let
        testTuple = types.tuple [
          types.string
          types.int
        ];
      in
      {
        testNotList = {
          expr = testTuple.inspect "xyz";
          expected = "in type 'tuple<string,int>': value '\"xyz\"' is not of type 'list'";
        };

        testInvalidLength = {
          expr = testTuple.inspect [ ];
          expected = "in type 'tuple<string,int>': expected tuple of length 2 but value '[ ]' has length 0";
        };

        testInvalidType = {
          expr = testTuple.inspect [
            123
            "xyz"
          ];
          expected = "in element 0 of type 'tuple<string,int>': value '123' is not of type 'string'";
        };

        testInvalidTypeTail = {
          expr = testTuple.inspect [
            "xyz"
            "123"
          ];
          expected = "in element 1 of type 'tuple<string,int>': value '\"123\"' is not of type 'int'";
        };

        testValid = {
          expr = testTuple.inspect [
            "xyz"
            123
          ];
          expected = null;
        };
      };

    defun =
      let
        check1 = types.defun "fn" [ types.string ] types.string;
        fn1 = check1 (s: "${s}-checked");
        check2 = types.defun "fn2" [ types.string types.int ] types.string;
        fn2 = check2 (s: n: "${s}-${toString n}-checked");
      in
      {
        testOk = {
          expr = fn1 "foo";
          expected = "foo-checked";
        };

        testWrongArg = {
          expr = fn1 1;
          expectedError.type = "ThrownError";
        };

        testWrongReturn =
          let
            fn = check1 (_: 2);
          in
          {
            expr = fn "foo";
            expectedError.type = "ThrownError";
          };

        testMultipleOk = {
          expr = fn2 "bar" 0;
          expected = "bar-0-checked";
        };

        testMultipleWrongArg = {
          expr = fn2 "bar" true;
          expectedError.type = "ThrownError";
        };
        testMultipleWrongReturn =
          let
            fn = check1 (_: [ ]);
          in
          {
            expr = fn "bar" 0;
            expectedError.type = "ThrownError";
          };
      };

    lazy = {
      attrsOf =
        let
          testLazyAttrsOf = types.lazy.attrsOf types.string;
        in
        {
          testValid = {
            expr = testLazyAttrsOf.inspect {
              x = "hello";
            };
            expected = null;
          };

          testValidStrict = {
            expr = testLazyAttrsOf.check {
              x = "hello";
            };
            expected = {
              x = "hello";
            };
          };

          testInvalidElemLazy = {
            expr = testLazyAttrsOf.inspect {
              x = 1;
            };
            expected = null;
          };

          testInvalidElemStrict = {
            expr = testLazyAttrsOf.check {
              x = 1;
            };
            expectedError.msg = "in type 'lazy.attrsOf<string>': in attribute 'x': value '1' is not of type 'string'";
          };

          testInvalidType = {
            expr = testLazyAttrsOf.inspect 1;
            expected = "value '1' is not of type 'lazy.attrsOf<string>'";
          };
        };

      listOf =
        let
          testLazyListOf = types.lazy.listOf types.string;
        in
        {
          testValid = {
            expr = testLazyListOf.inspect [ "hello" ];
            expected = null;
          };

          testValidStrict = {
            expr = testLazyListOf.check [ "hello" ];
            expected = [ "hello" ];
          };

          testInvalidElemLazy = {
            expr = testLazyListOf.inspect [ 1 ];
            expected = null;
          };

          testInvalidElemStrict = {
            expr = testLazyListOf.check [ 1 ];
            expectedError.msg = "in type 'lazy.listOf<string>': value '1' is not of type 'string'";
          };

          testInvalidType = {
            expr = testLazyListOf.inspect 1;
            expected = "in type 'lazy.listOf<string>': value '1' is not of type 'list'";
          };
        };
    };

    unsafe = {
      both =
        let
          safeType = types.both types.int (
            types.new {
              name = "positive";
              verify = v: v >= 0;
              apply = null;
            }
          );
          unsafeType = types.unsafe.both types.int (
            types.new {
              name = "positive";
              verify = v: v >= 0;
              apply = null;
            }
          );

          incrementThenDouble = types.unsafe.both incrementer doubler;
          doubleThenIncrement = types.unsafe.both doubler incrementer;

          # TODO: lazy type with mixed lazy-eager value test and all-lazy value test (check appropriate laziness)
        in
        {
          testSafe = {
            expr = unsafeType.check 2;
            expected = safeType.check 2;
          };
          testSafeInvalid = {
            expr = unsafeType.check (-1);
            expectedError.msg = "value '-1' is not of type 'unsafe.all<int,positive>'";
          };

          testOrdered = {
            expr = incrementThenDouble.check 2;
            expected = 6;
          };
          testReverseOrdered = {
            expr = doubleThenIncrement.check 2;
            expected = 5;
          };

          testOrderedNotOK = {
            expr = incrementThenDouble.inspect null;
            expected = "value 'null' is not of type 'unsafe.all<incrementer,doubler>'";
          };
        };

      intersection =
        let
          struct1 = types.struct "1" {
            a = types.number;
          };

          struct2 = types.struct "2" {
            a = types.int;
          };

          safeType = types.intersection [
            struct1
            struct2
          ];
          unsafeType = types.unsafe.intersection [
            struct1
            struct2
          ];

          # TODO: lazy type with mixed lazy-eager value test and all-lazy value test (check appropriate laziness)
        in
        {
          testSafe = {
            expr = unsafeType.check { a = 1; };
            expected = safeType.check { a = 1; };
          };

          testSafeInvalid = {
            expr = unsafeType.check 1;
            expectedError.type = "ThrownError";
          };
        };

      either =
        let
          safeType = types.either types.string types.bool;
          unsafeType = types.unsafe.either types.string types.bool;

          incrementType = types.unsafe.either incrementer doubler;
          doubleType = types.unsafe.either doubler incrementer;

          # TODO: lazy type with appropriate tests of lazyness

          # TODO: early-accept case, for submodule-likes - also put in union tests
        in
        {
          testFirst = {
            expr = unsafeType.check "hello";
            expected = safeType.check "hello";
          };
          testSecond = {
            expr = unsafeType.check false;
            expected = safeType.check false;
          };
          testInvalid = {
            expr = unsafeType.inspect 1;
            expected = "value '1' is not of type 'unsafe.either<string,bool>'";
          };

          testOrdered = {
            expr = incrementType.check 2;
            expected = 3;
          };
          testReverseOrdered = {
            expr = doubleType.check 2;
            expected = 4;
          };
          testOrderedInvalid = {
            expr = incrementType.inspect null;
            expected = "value 'null' is not of type 'unsafe.either<incrementer,doubler>'";
          };
        };

      union =
        let
          safeType = types.union [
            types.string
            types.bool
          ];
          unsafeType = types.unsafe.union [
            types.string
            types.bool
          ];

          incrementType = types.unsafe.union [
            incrementer
            doubler
          ];
          doubleType = types.unsafe.union [
            doubler
            incrementer
          ];

          # TODO: lazy type with appropriate tests of lazyness, like either
          # TODO: submodule type checks, like either
        in
        {
          testFirst = {
            expr = unsafeType.check "hello";
            expected = safeType.check "hello";
          };
          testSecond = {
            expr = unsafeType.check false;
            expected = safeType.check false;
          };

          testInvalid = {
            expr = unsafeType.inspect 1;
            expected = "in type 'unsafe.union<string,bool>': '1' is not a member of the union";
          };

          testOrdered = {
            expr = incrementType.check 2;
            expected = 3;
          };
          testReverseOrdered = {
            expr = doubleType.check 2;
            expected = 4;
          };

          testOrderedInvalid = {
            expr = incrementType.inspect null;
            expected = "in type 'unsafe.union<incrementer,doubler>': 'null' is not a member of the union";
          };
        };
    };

    recursiveTypes = {
      struct =
        let
          recursive = types.struct "recursive" {
            children = types.optionalAttr (types.attrsOf (types.rename "self" recursive));
          };
        in
        {
          testOK = {
            expr = recursive.inspect {
              children = {
                x = { };
              };
            };
            expected = null;
          };

          testNotOK = {
            expr = recursive.check {
              children = {
                x = "hello";
              };
            };
            expectedError.type = "ThrownError";
          };
        };

      attrsOf =
        let
          # Because attrsOf inherits names from it's sub-types we need to erase the name to not cause infinite recursion.
          # This should have it's own exposed function.
          type = types.attrsOf (
            types.rename "eitherType" (
              types.union [
                types.string
                type
              ]
            )
          );
        in
        {
          testOK = {
            expr = type.inspect {
              foo = "bar";
              baz = {
                foo = "bar";
                baz = {
                  foo = "bar";
                };
              };
            };
            expected = null;
          };

          testNotOK = {
            expr = type.check {
              foo = "bar";
              baz = {
                foo = "bar";
                baz = {
                  foo = "bar";
                  int = 1;
                };
              };
            };
            expectedError.type = "ThrownError";
          };
        };

      # TODO: listOf

      # TODO: test recursive lazyness, test preserving lazyness inside non-lazy types

      lazy = {
        attrsOf =
          let
            type = types.lazy.attrsOf (
              types.rename "eitherType" (
                types.union [
                  types.string
                  type
                ]
              )
            );
          in
          {
            testValidLazy = {
              expr = type.inspect {
                foo = "bar";
                baz = {
                  foo = "bar";
                  baz = {
                    foo = "bar";
                  };
                };
              };
              expected = null;
            };
            testValidStrict = {
              expr = type.check {
                foo = "bar";
                baz = {
                  foo = "bar";
                  baz = {
                    foo = "bar";
                  };
                };
              };
              expected = {
                foo = "bar";
                baz = {
                  foo = "bar";
                  baz = {
                    foo = "bar";
                  };
                };
              };
            };

            testInvalidLazy = {
              expr = type.inspect {
                foo = "bar";
                baz = {
                  foo = "bar";
                  baz = {
                    foo = "bar";
                    int = 1;
                  };
                };
              };
              expected = null;
            };
            testInvalidStrict = {
              expr = type.check {
                foo = "bar";
                baz = {
                  foo = "bar";
                  baz = {
                    foo = "bar";
                    int = 1;
                  };
                };
              };
              expectedError.type = "ThrownError";
            };
          };

        # TODO: meaningful apply semantics in lazy and recursive types, both separately and in combination
        either =
          let
            type = types.unsafe.either (types.lazy.attrsOf (types.rename "recurse" type)) (
              types.lazy.attrsOf types.string
            );
          in
          {
            testLazyTypesValid1 = {
              expr = type.inspect {
                foo = {
                  bar = {
                    baz = "foo";
                  };
                };
              };
              expected = null;
            };

            testLazyTypesValid2 = {
              expr = type.inspect {
                foo = "bar";
              };
              expected = null;
            };

            testLazyTypesInvalidLazy = {
              expr = type.inspect {
                foo = 1;
              };
              expected = null;
            };
            testLazyTypesInvalidStrict = {
              expr = type.check {
                foo = 1;
              };
              expectedError.msg = "in type 'lazy.attrsOf<string>': in attribute 'foo': value '1' is not of type 'string'";
            };

            testLazyTypesInvalidType = {
              expr = type.inspect 1;
              expected = "value '1' is not of type 'unsafe.either<lazy.attrsOf<recurse>,lazy.attrsOf<string>>'";
            };
          };

        # TODO: lazy.listOf
      };
    };
  }
)
