# run `nix-unit adios/tests.nix` to see if the tests pass
let
  inherit (builtins) foldl' mapAttrs substring;

  adios = import ../.;
  inherit (adios) types;

  isTest = name: substring 0 4 name == "test";
  ignoredTestAttributes = [
    "module"
    "modules"
    "apply"
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
        ) { };
      in
      removeAttrs test ignoredTestAttributes
      // {
        expr = (if test ? apply then test.apply else tree: tree { }) tree;
      };

in
mapAttrs testModules {
  testBasic = {
    module = {
      impl = { options }: true;
    };
    expected = true;
  };

  default = {
    testDefaultWorks = {
      module = {
        options.test = {
          type = types.bool;
          default = true;
        };
        impl = { options }: options.test;
      };
      expected = true;
    };

    testDefaultFuncWorks = {
      module = {
        options.test = {
          type = types.bool;
          defaultFunc = { inputs }: true;
        };
        impl = { options }: options.test;
      };
      expected = true;
    };

    testInvalidTogether = {
      module = {
        options.test = {
          type = types.bool;
          default = true;
          defaultFunc = { inputs }: true;
        };
        impl = { options }: options.test;
      };
      expectedError.type = "ThrownError";
    };

  };

  inputs = {
    testSelf = {
      module = {
        inputs.test.from = { self }: self.test;
        modules.test = {
          options.option = {
            default = 1;
            type = types.int;
          };
          impl = _: true;
        };
        impl =
          { inputs }:
          assert inputs.test.option == 1;
          inputs.test { };
      };
      expected = true;
    };

    testParent = {
      modules = {
        mod1.impl = _: true;
        mod2.impl = _: true;
        test = {
          inputs = {
            mod1.from = { parent }: parent.mod1;
            mod2.from = { parent }: parent.mod2;
          };
          impl = { inputs }: (inputs.mod1 { }) && (inputs.mod2 { });
        };
      };
      apply = tree: tree.modules.test { };
      expected = true;
    };

    testRoot = {
      module = {
        inputs.test.from = { root }: root.test;
        modules.test.impl = _: true;
        impl = { inputs }: inputs.test { };
      };
      expected = true;
    };

    testParentRootAndSelf = {
      module = {
        inputs.test.from =
          {
            root,
            parent,
            self,
          }:
          root.test;
        modules.test.impl = _: true;
        impl = { inputs }: inputs.test { };
      };
      expected = true;
    };

    testSelfCallable = {
      module = {
        options = {
          ranOnce = {
            type = types.bool;
            default = false;
          };
        };
        impl = { options }: if options.ranOnce then true else options { ranOnce = true; };
      };
      expected = true;
    };
  };
  laziness = {
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
        impl = { options }: options.called;
      };
      expected = true;
    };

    testNoValueOption = {
      module = {
        options = {
          noDefault = {
            type = types.string;
          };
        };
        impl =
          { options }:
          assert !options ? noDefault;
          true;
      };
      expected = true;
    };
  };

  mutators = {
    testValid = {
      modules = {
        mutator1 = {
          mutations."/getsMutated".test = _: 1;
        };
        mutator2 = {
          mutations."/getsMutated".test = _: 2;
        };
        mutator3 = {
          mutations."/getsMutated".test = _: 3;
        };
        unsetMutator = {
          mutations."/getsMutated".test = _: 100;
        };
        getsMutated = {
          options.test = {
            type = types.int;
            mutatorType = types.int;
            mutators = [
              "/mutator1"
              "/mutator2"
              "/mutator3"
            ];
            mergeFunc = { mutators }: foldl' (acc: v: acc + v) 0 (mutators);
          };
          impl = { options }: options.test;
        };
      };
      apply = tree: tree.modules.getsMutated { };
      expected = 6;
    };
  };

  submodules = {
    testValid = {
      module = {
        options.test.options = {
          field1.type = types.bool;
          field1.default = true;
          field2.type = types.bool;
          field2.default = true;
        };
        impl = { options }: options.test.field1 && options.test.field2;
      };
      expected = true;
    };
  };
}
