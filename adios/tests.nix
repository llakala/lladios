# run `nix-unit adios/tests.nix` to see if the tests pass
let
  inherit (builtins)
    deepSeq
    foldl'
    mapAttrs
    substring
    ;

  adios = import ../.;
  inherit (adios) types promise;

  isTest = name: substring 0 4 name == "test";
  ignoredTestAttributes = [
    "module"
    "modules"
    "apply"
    "evalParams"
  ];
  normalTestAttributes = [
    "expr"
    "expected"
    "expectedError"
  ];

  testModules =
    testName: test:
    if !isTest testName then
      mapAttrs testModules test
    else
      let
        tree = adios (
          if test ? modules then
            { inherit (test) modules; }
          else if test ? module then
            test.module
          else
            throw "test didn't provide a 'modules' or 'module' argument!"
        ) (if test ? evalParams then test.evalParams else { });
      in
      if test ? expr then
        assert removeAttrs test normalTestAttributes == { };
        test
      else
        removeAttrs test ignoredTestAttributes
        // {
          expr = (if test ? apply then test.apply else tree: tree { }) tree;
        };

in
mapAttrs testModules {
  basic = {
    testCalling = {
      module = {
        result = true;
      };
      expected = true;
    };

    testDefaultWorks = {
      module = {
        options.test = {
          type = types.bool;
          default = true;
        };
        result = promise ({ options }: options.test);
      };
      expected = true;
    };

    testNonexistentParams = {
      module = {
        options.foo.type = types.bool;
        options.bar.type = types.bool;
        result = promise ({ options }: builtins.seq options true);
      };
      apply = module: module { baz = false; };
      expectedError.msg = "while calling /: tried to set nonexistent option 'baz', valid options were '\\[bar, foo\\]'";
    };

    testBadModuleType = {
      module = adios: { result = true; };
      apply = tree: tree;
      expectedError.msg = ''
        in module '/': module is of type 'function', but Adios modules should be attrsets.
        \s+hint: since your module is a function, you probably expected it to be called with
        \s+'adios' automatically. To do this, use 'adios.lib.importModules' on a directory'';
    };

    testTypecheckFailure = {
      module = {
        options.test = {
          default = 0;
          type = types.string;
        };
        result = promise ({ options }: options.test);
      };
      expectedError.msg = "value '0' is not of type 'string'";
    };

    testAllAttributes = {
      module = {
        options.some-option.options.some-suboption.type = types.int;
        inputs.some-input.from = { self }: self.some-child;
        modules.some-child.result = 5;
        types = {
          type1 = types.int;
          nested.type2 = types.string;
        };
        lib = {
          func1 = a: true;
          nested.func2 = b: false;
        };
        mutations."/some-module".some-option = true;
        result = true;
      };
      apply = tree: deepSeq tree true;
      expected = true;
    };
  };

  inputs = {
    testSelf = {
      module = {
        inputs.test.from = { self }: self.test;
        inputs.test.options.some-option = 2;
        modules.test = {
          options.some-option = {
            default = 1;
            type = types.int;
          };
          result = true;
        };
        result = promise (
          { inputs, results }:
          assert inputs.test.some-option == 2;
          results.test
        );
      };
      expected = true;
    };

    testParent = {
      modules = {
        mod1 = {
          options.favorite-number = {
            type = types.int;
            default = 10;
          };
          result = true;
        };
        mod2 = {
          options.favorite-number.type = types.int;
          result = promise ({ options }: options ? favorite-number);
        };
        test = {
          inputs = {
            mod1.from = { parent }: parent.mod1;
            mod2.from = { parent }: parent.mod2;
            mod2.options.favorite-number = promise ({ inputs }: inputs.mod1.favorite-number);
          };
          result = promise ({ results }: results.mod1 && results.mod2);
        };
      };
      apply = tree: tree.modules.test { };
      expected = true;
    };

    testRoot = {
      module = {
        inputs.test.from = { root }: root.test;
        modules.test.result = true;
        result = promise ({ results }: results.test);
      };
      expected = true;
    };

    # inputs.$foo.from is called with intersectAttrs - you should be able to use
    # multiple
    testParentRootAndSelf = {
      module = {
        inputs.test.from =
          {
            root,
            parent,
            self,
          }:
          root.test;
        modules.test.result = true;
        result = promise ({ results }: results.test);
      };
      expected = true;
    };

    testNoParentOfRoot = {
      module = {
        inputs.parentOfRoot.from = { parent }: parent;
        result = promise ({ inputs }: inputs.parentOfRoot);
      };
      expectedError.msg = "Attempted to access parent of root module, but the root module has no parent!";
    };

    testOwnResult = {
      module = {
        result = promise (
          { result }: {
            a = 0;
            b = result.a + 1;
          }
        );
      };
      expected = {
        a = 0;
        b = 1;
      };
    };
  };

  laziness = {
    # only the attrNames of options are expected to be forced in this case, not
    # the attrValues
    testUnusedOption = {
      module = {
        options = {
          neverCalled = {
            type = types.bool;
            default = throw "should error";
          };
          called = {
            type = types.bool;
            default = true;
          };
        };
        result = promise ({ options }: options.called);
      };
      expected = true;
    };

    # Options without a default or passed value shouldn't be included in the
    # options attrset
    testNoValueOption = {
      module = {
        options = {
          noDefault = {
            type = types.string;
          };
        };
        result = promise (
          { options }:
          assert !options ? noDefault;
          true
        );
      };
      expected = true;
    };
  };

  mutators = {
    testValid = {
      modules = {
        mutator1 = {
          mutations."/getsMutated".test = 1;
        };
        mutator2 = {
          mutations."/getsMutated".test = 2;
        };
        mutator3 = {
          mutations."/getsMutated".test = promise (_: 3);
        };
        # this isn't in the mutators list, so it's completely ignored
        unsetMutator = {
          mutations."/getsMutated".test = 100;
        };
        getsMutated = {
          options.test = {
            type = types.int;
            mutators = [
              "/mutator1"
              "/mutator2"
              "/mutator3"
            ];
            # add the values
            mergeFunc = { mutators }: foldl' (acc: v: acc + v) 0 mutators;
          };
          result = promise ({ options }: options.test);
        };
      };
      apply = tree: tree.modules.getsMutated { };
      expected = 6;
    };

    # when mutating own module, options set while calling should be propagated
    # to the mutation, rather than using the old args fixpoint
    testMutationOfOwnModule = {
      module = {
        options.mutatedOption = {
          type = types.list;
          mutators = [ "/" ];
          mergeFunc = adios.lib.merge.lists.concat;
        };
        options.implStageOption = {
          type = types.string;
        };
        mutations."/".mutatedOption = promise ({ options }: [ options.implStageOption ]);
        result = promise ({ options }: options.mutatedOption);
      };
      apply = tree: tree { implStageOption = "demo"; };
      expected = [ "demo" ];
    };

    # 'mergeFunc' must be set if 'mutators' are
    testMutatorsWithoutMergeFunc = {
      module = {
        options.foo = {
          type = types.bool;
          mutators = [ ];
        };
        result = promise ({ options }: options.foo);
      };
      expectedError.msg = "in struct 'option': if 'mutators' are specified, 'mergeFunc' must be as well";
    };
  };

  evalStage = {
    testValid = {
      module = {
        options.test = {
          type = types.string;
          default = "hello world";
        };
        result = promise ({ options }: options.test);
      };
      evalParams = {
        options."/".test = "goodbye world";
      };
      expected = "goodbye world";
    };
  };

  submodules = {
    testValid = {
      module = {
        options.test = {
          example = "we can add examples without erroring";
          description = "and descriptions";
          options = {
            field1.type = types.bool;
            field1.default = true;
            field2.type = types.bool;
            field2.default = true;
          };
        };
        result = promise ({ options }: options.test.field1 && options.test.field2);
      };
      expected = true;
    };

    # submodules must only provide the `options` field, no `type` / `default`
    # allowed
    testNoOtherFieldsAllowed = {
      module = {
        options.test = {
          type = types.int;
          default = 5;
          options.subfield.type = types.bool;
        };
        result = promise ({ options }: options.test);
      };
      expectedError.msg = "in struct 'subOptions': keys \\['default', 'type'\\] are unrecognized, expected keys are \\['description', 'example', 'options'\\]";
    };
  };

  injections = {
    testBasicDefaultSetting = {
      module = adios.lib.inject [
        {
          options.test.type = types.bool;
          result = promise ({ options }: options.test);
        }
        {
          options.test.default = true;
        }
      ];
      expected = true;
    };

    testPromiseMappingNonPromise = {
      module = adios.lib.inject [
        {
          options.test = {
            type = types.int;
            default = 10;
          };
          result = promise ({ options }: options.test);
        }
        {
          options.test.default = promise.map (prev: prev + 1);
        }
      ];
      expected = 11;
    };

    testPromiseMappingPromise = {
      module = adios.lib.inject [
        {
          options.hello = {
            type = types.string;
            default = "hello";
          };
          result = promise ({ options }: options.hello);
        }
        {
          result = promise.map (prev: prev + " world");
        }
      ];
      expected = "hello world";
    };
    testTriplePromise = {
      module = adios.lib.inject [
        {
          result = promise (_: 2);
        }
        {
          result = promise.map (prev: prev * 3);
        }
        {
          result = promise.map (prev: prev + 1);
        }
      ];
      expected = 7;
    };
  };

  mergeFuncs = {
    mergeAttrsFlat = {
      testSuccess = {
        expr = adios.lib.merge.attrs.flat {
          mutators = [
            { a = 1; }
            { b = 2; }
            { c.d = 3; }
          ];
        };
        expected = {
          a = 1;
          b = 2;
          c.d = 3;
        };
      };

      # the toplevel keys must be disjoint
      testFailure = {
        expr = adios.lib.merge.attrs.flat {
          mutators = [
            { foo.bar = 1; }
            { foo.baz = 2; }
          ];
        };
        expectedError.msg = ''
          while calling 'adios.lib.merge.attrs.flat':
          while attempting to merge mutators '\[
            \{ foo = \{ bar = 1; }; }
            \{ foo = \{ baz = 2; }; }
          ]':
          found multiple mutators attempting to set key 'foo''\''';
      };
    };

    mergeAttrsRecursively = {
      testSuccess = {
        expr = adios.lib.merge.attrs.recursively {
          mutators = [
            { foo.bar = 1; }
            { foo.baz = 2; }
          ];
        };
        expected = {
          foo.bar = 1;
          foo.baz = 2;
        };
      };

      testFailure = {
        expr = adios.lib.merge.attrs.recursively {
          mutators = [
            { foo.bar = 1; }
            { foo.bar = 2; }
          ];
        };
        expectedError.msg = ''
          while calling 'adios.lib.merge.attrs.recursively':
          while attempting to merge mutators \[
            \{ foo = \{ bar = 1; }; }
            \{ foo = \{ bar = 2; }; }
          ]
          found key 'bar' set to multiple values that couldn't be merged
          unmergeable values: \[ 1 2 ]'';
      };
    };

    withOrder = {
      testSuccess = {
        expr = adios.lib.merge.general.withOrder adios.lib.merge.lists.concat {
          mutators = [
            {
              value = [ "hello" ];
              order = 1;
            }
            {
              value = [ "world" ];
              order = 2;
            }
          ];
        };
        expected = [
          "hello"
          "world"
        ];
      };
    };
  };
}
