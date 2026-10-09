{ types, promise, ... }:
{
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
}
