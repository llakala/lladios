# run `nix-unit korora/tests.nix` to see if the tests pass
{
  sources ? import ../npins,
  lib ? import (sources.nixpkgs + "/lib"),
}:

let
  inherit (builtins)
    isInt
    isFloat
    isString
    substring
    stringLength
    ;
  inherit (lib) toUpper;

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
    rename = true;
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
        testApply = types.listOf (
          types.new {
            name = "lazy-positive-int";
            verify = isInt;
            apply = v: if v < 0 then throw "${toString v} less than 0" else null;
          }
        );
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

        testApply = {
          expr = testApply.check [
            1
            2
            (-1)
          ];
          expectedError.type = "ThrownError";
        };
      };

    attrsOf =
      let
        testAttrsOf = types.attrsOf types.string;
        testApply = types.attrsOf (
          types.new {
            name = "list-doubler";
            inherit (types.listOf types.int) verify;
            apply = map (v: v * 2);
          }
        );
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

        testApply = {
          expr = testApply.check {
            a = [ ];
            b = [
              1
              3
            ];
          };
          expected = {
            a = [ ];
            b = [
              2
              6
            ];
          };
        };
      };

    union =
      let
        testUnion = types.union [
          types.string
          types.bool
        ];
        intDoubler = types.new {
          name = "int-doubler";
          verify = isInt;
          apply = v: v * 2;
        };
        testApply = types.union [
          types.string
          intDoubler
        ];
        floatTripler = types.new {
          name = "float-tripler";
          verify = isFloat;
          apply = v: v * 3;
        };
        testApply2 = types.union [
          types.string
          intDoubler
          floatTripler
        ];
        thrower = types.new {
          name = "thrower";
          verify = _v: throw "no";
          apply = v: v * 2; # has apply semantics
        };
        testApply3 = types.union [
          types.string
          thrower
          types.int
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

        testApplyValid = {
          expr = testApply.check 5;
          expected = 10;
        };

        # only one type with apply semantics allowed
        testApplyInvalid = {
          expr = testApply2;
          expectedError.type = "ThrownError";
        };

        # TODO: is that still true?
        # types with apply semantics are verified last
        testApplyLazy = {
          expr = testApply3.verify 20;
          expected = true;
        };
      };

    either =
      let
        testEither = types.either types.string types.bool;
        worldAppender = types.new {
          name = "world-appender";
          verify = isString;
          apply = v: v + "world";
        };
        testApply1 = types.either types.bool worldAppender;
        thrower = types.new {
          name = "thrower";
          verify = _v: throw "no";
          apply = v: v * 2; # has apply semantics
        };
        testApply2 = types.either thrower types.bool;
        testApply3 = types.either worldAppender thrower;
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

        testApply = {
          expr = testApply1.check "hello";
          expected = "helloworld";
        };

        testApplyLazy = {
          expr = testApply2.check true;
          expected = true;
        };

        testApplyInvalid = {
          expr = testApply3;
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
        doubler = types.new {
          name = "doubler";
          verify = v: isInt v || isFloat v;
          apply = v: v * 2;
        };
        testApply = types.intersection [
          doubler
          types.int
        ];
        testApply2 = types.intersection [
          doubler
          doubler
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

        testApply = {
          expr = testApply.check 2;
          expected = 4;
        };

        testApply2 = {
          expr = testApply.inspect 5.0;
          expected = "value '5.0' is not of type 'intersection<doubler,int>'";
        };

        testApplyInvalid = {
          expr = testApply2;
          expectedError.type = "ThrownError";
        };
      };

    both =
      let
        positive = types.new {
          name = "positive";
          verify = v: v >= 0;
          apply = null;
        };
        negater = types.new {
          name = "negater";
          verify = _v: true;
          apply = v: v * -1;
        };
        testBoth = types.both types.int positive;
        testApply = types.both testBoth negater;
        testApply2 = types.both negater negater;
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
        testApply = {
          expr = testApply.check 5;
          expected = 5;
        };
        testApplyInvalid = {
          expr = testApply2;
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
        testApply = types.nullOr (
          types.new {
            name = "demo";
            verify = isInt;
            apply = v: v + 1;
          }
        );
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

        testApply = {
          expr = testApply.check 1;
          expected = 2;
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
              explain = _v: "VERBOTEN";
            };

        testStructCustomVerifyNoExplain = testStructCustomVerify.override {
          verify = v: v.x + v.y != 2;
        };

        testApplyStruct = types.struct "applier" {
          z = types.new {
            name = "int-doubler";
            verify = isInt;
            apply = v: v * 2;
          };
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

        testApply = {
          expr = testApplyStruct.check {
            z = 1;
          };
          expected = {
            z = 2;
          };
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
        testOverride = types.struct "applier" {
          foo = ((types.optionalAttr types.int).override { }).override { };
        };
        testOverride2 = types.struct "applier" {
          foo = (types.optionalAttr types.int).override {
            verify = v: isInt v || isFloat v;
          };
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

        testOverrideChaining = {
          expr = testOverride.inspect {
            foo = 2;
          };
          expected = null;
        };

        testWithoutOptionalOverriden = {
          expr = testOverride2.inspect { };
          expected = null;
        };

        testWithOptionalOverriden = {
          expr = testOverride2.inspect {
            foo = 1.5;
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

    tuple =
      let
        testTuple = types.tuple [
          types.string
          types.int
        ];
        testApplyTuple = types.tuple [
          types.int
          types.bool
          (types.new {
            name = "world-appender";
            verify = isString;
            apply = v: v + "world";
          })
        ];
      in
      {
        testValid = {
          expr = testTuple.inspect [
            "xyz"
            123
          ];
          expected = null;
        };

        testApply = {
          expr = testApplyTuple.check [
            1
            true
            "hello"
          ];
          expected = [
            1
            true
            "helloworld"
          ];
        };

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
          lazyAttrsOf = types.lazy.attrsOf types.string;
        in
        {
          testValid = {
            expr = lazyAttrsOf.lazyInspect {
              x = "hello";
            };
            expected = null;
          };

          testValidStrict = {
            expr = lazyAttrsOf.inspect {
              x = "hello";
            };
            expected = null;
          };

          testInvalidElemLazy = {
            expr = lazyAttrsOf.lazyInspect {
              x = 1;
            };
            expected = null;
          };

          testInvalidElemStrict = {
            # HACK: The apply error message is significantly better than the explain output.
            # Ideally, they have relative parity.
            expr = lazyAttrsOf.inspect {
              x = 1;
            };
            # HACK: equivalent multiline version would be much more readable
            expected = "value '{\n      x = 1;\n    }' is not of type 'lazy.attrsOf<string>'";
          };

          testInvalidType = {
            expr = lazyAttrsOf.inspect 1;
            expected = "value '1' is not of type 'lazy.attrsOf<string>'";
          };
        };

      listOf =
        let
          lazyListOf = types.lazy.listOf types.string;
        in
        {
          testValid = {
            expr = lazyListOf.lazyInspect [ "hello" ];
            expected = null;
          };

          testValidStrict = {
            expr = lazyListOf.inspect [ "hello" ];
            expected = null;
          };

          testInvalidElemLazy = {
            expr = lazyListOf.lazyInspect [ 1 ];
            expected = null;
          };

          testInvalidElemStrict = {
            # HACK: The apply error message is significantly better than the explain output.
            # Ideally, they have relative parity.
            expr = lazyListOf.inspect [ 1 ];
            expected = "in type 'lazy.listOf<string>': in element: value '1' is not of type 'string'";
          };

          testInvalidType = {
            expr = lazyListOf.lazyInspect 1;
            expected = "in type 'lazy.listOf<string>': value '1' is not of type 'list'";
          };
        };
    };

    unsafe = {
      both =
        let
          positive = types.new {
            name = "positive";
            verify = v: v >= 0;
            apply = null;
          };
          incrementer = types.new {
            name = "incrementer";
            verify = v: isInt v || isFloat v;
            apply = v: v + 1;
          };
          intDoubler = types.new {
            name = "int-doubler";
            verify = isInt;
            apply = v: v * 2;
          };

          safeType = types.both types.int positive;
          unsafeType = types.unsafe.both types.int positive;

          incrementThenDouble = types.unsafe.both incrementer intDoubler;
          doubleThenIncrement = types.unsafe.both intDoubler incrementer;

          # TODO: lazy type with mixed lazy-eager value test and all-lazy value test (check appropriate laziness)
        in
        {
          testSafe = {
            expr = unsafeType.check 2;
            expected = safeType.check 2;
          };
          testSafeInvalid = {
            expr = unsafeType.inspect (-1);
            expected = "value '-1' is not of type 'unsafe.all<int,positive>'";
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
            expected = "value 'null' is not of type 'unsafe.all<incrementer,int-doubler>'";
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
            expr = unsafeType.inspect 1;
            expected = "value '1' is not of type 'unsafe.intersection<struct<1>,struct<2>>'";
          };
        };

      either =
        let
          incrementer = types.new {
            name = "incrementer";
            verify = v: isInt v || isFloat v;
            apply = v: v + 1;
          };
          intDoubler = types.new {
            name = "int-doubler";
            verify = isInt;
            apply = v: v * 2;
          };

          safeType = types.either types.string types.bool;
          unsafeType = types.unsafe.either types.string types.bool;

          incrementType = types.unsafe.either incrementer intDoubler;
          doubleType = types.unsafe.either intDoubler incrementer;

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
            expected = "value 'null' is not of type 'unsafe.either<incrementer,int-doubler>'";
          };
        };

      union =
        let
          incrementer = types.new {
            name = "incrementer";
            verify = v: isInt v || isFloat v;
            apply = v: v + 1;
          };
          intDoubler = types.new {
            name = "int-doubler";
            verify = isInt;
            apply = v: v * 2;
          };

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
            intDoubler
          ];
          doubleType = types.unsafe.union [
            intDoubler
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
            expected = "in type 'unsafe.union<incrementer,int-doubler>': 'null' is not a member of the union";
          };
        };
    };

    recursiveTypes = {
      struct =
        let
          recursive = types.struct "recursive" {
            children = types.optionalAttr (
              types.attrsOf (
                recursive.override {
                  name = "recursive";
                  apply = null;
                }
              )
            );
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
            expr = recursive.inspect {
              children = {
                x = "hello";
              };
            };
            expected = "in struct 'recursive': in member 'children': in type 'attrsOf<recursive>': in attribute 'x': in struct 'recursive': value '\"hello\"' is not of type 'attrs'";
          };
        };

      applies =
        let
          recursiveType = types.struct "recursive" {
            signed = types.new {
              name = "signer"; # signs the attrset as checked
              verify = builtins.isAttrs;
              apply = v: v // { checked = true; };
            };
            children = types.optionalAttr (
              recursiveType.override {
                apply = v: recursiveType.apply v;
              }
            );
          };
        in
        {
          testOK = {
            expr = recursiveType.check {
              signed = { };
              children.signed = { };
            };
            expected = {
              signed.checked = true;
              children.signed.checked = true;
            };
          };
        };

      attrsOf =
        let
          # Because attrsOf inherits names and apply semantics from its
          # subtypes, we erase them to not cause infinite recursion.
          type = types.attrsOf (
            types.union [
              types.string
              (type.override {
                name = "self";
                apply = null;
              })
            ]
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
            # HACK: equivalent multiline version would be much more readable
            expected = "in type 'attrsOf<union<string,self>>': in attribute 'baz': in type 'union<string,self>': '{\n      baz = {\n        foo = \"bar\";\n        int = 1;\n      };\n      foo = \"bar\";\n    }' is not a member of the union";
          };
        };

      # TODO: listOf

      # TODO: test recursive lazyness, test preserving lazyness inside non-lazy types

      lazy = {
        attrsOf =
          let
            lazyAttrsOf = types.lazy.attrsOf (
              types.either types.string (
                lazyAttrsOf.override {
                  name = "self";
                  # If types.string had apply semantics, we would want to propagate them here (if types.string.strictVerify was successful).
                  apply = null;
                }
              )
            );
          in
          {
            testValidLazy = {
              expr = lazyAttrsOf.lazyInspect {
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
              expr = lazyAttrsOf.inspect {
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

            testInvalidLazy = {
              expr = lazyAttrsOf.lazyInspect {
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
              expr = lazyAttrsOf.inspect {
                foo = "bar";
                baz = {
                  foo = "bar";
                  baz = {
                    foo = "bar";
                    baz = 1;
                  };
                };
              };
              # TODO: better explain
              expected = "value '{\n      baz = {\n        baz = {\n          baz = 1;\n          foo = \"bar\";\n        };\n        foo = \"bar\";\n      };\n      foo = \"bar\";\n    }' is not of type 'lazy.attrsOf<either<string,self>>'";
            };
          };

        # TODO: meaningful apply semantics in lazy and recursive types, both separately and in combination
        either =
          let
            either = types.unsafe.either (types.lazy.attrsOf (
              either.override {
                name = "recurse";
                apply = null;
              }
            )) (types.lazy.attrsOf types.string);
          in
          {
            testLazyTypesValid1 = {
              expr = either.lazyInspect {
                foo = {
                  bar = {
                    baz = "foo";
                  };
                };
              };
              expected = null;
            };

            testLazyTypesValid2 = {
              expr = either.lazyInspect {
                foo = "bar";
              };
              expected = null;
            };

            testLazyTypesInvalidLazy = {
              expr = either.lazyInspect {
                foo = 1;
              };
              expected = null;
            };
            testLazyTypesInvalidStrict = {
              expr = either.inspect {
                foo = 1;
              };
              # HACK: equivalent multiline version would be much more readable
              expected = "value '{\n      foo = 1;\n    }' is not of type 'unsafe.either<lazy.attrsOf<recurse>,lazy.attrsOf<string>>'";
            };

            testLazyTypesInvalidType = {
              expr = either.inspect 1;
              expected = "value '1' is not of type 'unsafe.either<lazy.attrsOf<recurse>,lazy.attrsOf<string>>'";
            };
          };
      };
    };
  }
)
