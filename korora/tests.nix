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
    findFirstValue = true;
    findFirstFunction = true;
    typedef = true;
    typedef' = true;
    new = true;
  };

  addCoverage =
    public: tests:
    (
      assert !tests ? coverage;
      tests
      // {
        coverage = lib.mapAttrs' (n: _v: {
          name = "test" + (capitalise n);
          value = {
            expr = tests ? ${n} || untestedTypes ? ${n};
            expected = true;
          };
        }) public;
      }
    );

in
lib.fix (
  self:
  addCoverage types {
    string = {
      testInvalid = {
        expr = types.string.inspect 1;
        expected = "Expected type 'string' but value '1' failed the type check";
      };

      testValid = {
        expr = types.string.inspect "Hello";
        expected = null;
      };
    };

    function = {
      testInvalid = {
        expr = types.function.inspect 1;
        expected = "Expected type 'function' but value '1' failed the type check";
      };

      testValid = {
        expr = types.function.inspect (_: null);
        expected = null;
      };
    };

    path = {
      testInvalid = {
        expr = types.path.inspect 1;
        expected = "Expected type 'path' but value '1' failed the type check";
      };

      testValid = {
        expr = types.path.inspect ./.;
        expected = null;
      };
    };

    pathLike = {
      testInvalid = {
        expr = types.pathLike.inspect 1;
        expected = "Expected type 'pathLike' but value '1' failed the type check";
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
        expected = "Expected type 'derivation' but value '{ }' failed the type check";
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
        expected = "Expected type 'never' but value '1234' failed the type check";
      };
    };

    int = {
      testInvalid = {
        expr = types.int.inspect "x";
        expected = "Expected type 'int' but value '\"x\"' failed the type check";
      };

      testValid = {
        expr = types.int.inspect 1;
        expected = null;
      };
    };

    float = {
      testInvalid = {
        expr = types.float.inspect "x";
        expected = "Expected type 'float' but value '\"x\"' failed the type check";
      };

      testValid = {
        expr = types.float.inspect 1.0;
        expected = null;
      };
    };

    number = {
      testInvalid = {
        expr = types.number.inspect "x";
        expected = "Expected type 'number' but value '\"x\"' failed the type check";
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
        expected = "Expected type 'bool' but value '\"x\"' failed the type check";
      };

      testValid = {
        expr = types.bool.inspect true;
        expected = null;
      };
    };

    null = {
      testInvalid = {
        expr = types.null.inspect "x";
        expected = "Expected type 'null' but value '\"x\"' failed the type check";
      };

      testValid = {
        expr = types.null.inspect null;
        expected = null;
      };
    };

    attrs = {
      testInvalid = {
        expr = types.attrs.inspect "x";
        expected = "Expected type 'attrs' but value '\"x\"' failed the type check";
      };

      testValid = {
        expr = types.attrs.inspect { };
        expected = null;
      };
    };

    list = {
      testInvalid = {
        expr = types.list.inspect "x";
        expected = "Expected type 'list' but value '\"x\"' failed the type check";
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
          expected = "in listOf<string> element: Expected type 'string' but value '1' failed the type check";
        };

        testInvalidType = {
          expr = testListOf.inspect 1;
          expected = "Expected type 'listOf<string>' but value '1' failed the type check";
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
          expected = "in attrsOf<string> value: in attribute 'x': Expected type 'string' but value '1' failed the type check";
        };

        testInvalidType = {
          expr = testAttrsOf.inspect 1;
          expected = "Expected type 'attrsOf<string>' but value '1' failed the type check";
        };
      };

    union =
      let
        testUnion = types.union [ types.string ];
      in
      {
        testValid = {
          expr = testUnion.inspect "hello";
          expected = null;
        };

        testInvalid = {
          expr = testUnion.inspect 1;
          expected = "Expected type 'union<string>' but value '1' failed the type check";
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
          expected = "Expected type 'intersection<struct<1>,struct<2>>' but value '1' failed the type check";
        };
      };

    type = {
      testValid = {
        expr = types.type.inspect types.string;
        expected = null;
      };

      testInvalid = {
        expr = types.type.inspect { };
        expected = "Expected type 'type' but value '{ }' failed the type check";
      };
    };

    nullOr =
      let
        testOption = types.nullOr types.string;
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
          expected = "in nullOr<string>: Expected type 'string' but value '3' failed the type check";
        };
      };

    struct =
      let
        testStruct = types.struct "test1" {
          foo = types.string;
        };

        testStruct2 =
          (types.struct "test2" {
            x = types.int;
            y = types.int;
          }).override
            {
              verify = v: v.x + v.y != 2;
              explain = v: "VERBOTEN";
            };

        testStructNonTotal = testStruct.override { total = false; };
        testStructWithUnknown = testStruct.override { unknown = true; };
      in
      {
        testValid = {
          expr = testStruct.inspect {
            foo = "bar";
          };
          expected = null;
        };

        testMissingAttr = {
          expr = testStruct.inspect { };
          expected = "in 'struct<test1>': missing member 'foo'";
        };

        testNonTotal = {
          expr = testStructNonTotal.inspect { };
          expected = null;
        };

        testExtraInvariantCheck = {
          expr = testStruct2.inspect {
            x = 1;
            y = 1;
          };
          expected = "in 'struct<test2>': VERBOTEN";
        };

        testUnknownAttrNotAllowed = {
          expr = testStruct.inspect {
            foo = "bar";
            bar = "foo";
          };
          expected = "in 'struct<test1>': keys ['bar'] are unrecognized, expected keys are ['foo']";
        };

        testUnknownAttr = {
          expr = testStructWithUnknown.inspect {
            foo = "bar";
            bar = "foo";
          };
          expected = null;
        };

        testInvalidType = {
          expr = testStruct.inspect "bar";
          expected = "in 'struct<test1>': Expected type 'struct<test1>' but value '\"bar\"' failed the type check";
        };

        testInvalidMember = {
          expr = testStruct.inspect {
            foo = 1;
          };
          expected = "in 'struct<test1>': in member 'foo': Expected type 'string' but value '1' failed the type check";
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
          expected = "in 'struct<testOptionalAttr>': in member 'optionalFoo': in optionalAttr<string>: Expected type 'string' but value '1234' failed the type check";
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
          expected = "'\"nope\"' is not a member of enum 'testEnum'";
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
          expected = "in tuple<string,int>: Expected type 'tuple<string,int>' but value '\"xyz\"' failed the type check";
        };

        testInvalidLength = {
          expr = testTuple.inspect [ ];
          expected = "in tuple<string,int>: Expected tuple to have length 2 but value '[ ]' has length 0";
        };

        testInvalidType = {
          expr = testTuple.inspect [
            123
            "xyz"
          ];
          expected = "in tuple<string,int>: in element 0: Expected type 'string' but value '123' failed the type check";
        };

        testInvalidTypeTail = {
          expr = testTuple.inspect [
            "xyz"
            "123"
          ];
          expected = "in tuple<string,int>: in element 1: Expected type 'int' but value '\"123\"' failed the type check";
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

    recursiveTypes = {
      struct =
        let
          recursive = types.struct "recursive" {
            children = types.optionalAttr (types.attrsOf recursive);
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
    };
  }
)
