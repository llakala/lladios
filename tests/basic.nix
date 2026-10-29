{ types, promise, ... }:
{
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
      hint: since your module is a function, you probably expected it to be called with
      'adios' automatically. To do this, use 'adios.lib.importModules' on a directory'';
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
      modules.some-child.result = true;
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
    apply = tree: builtins.deepSeq tree true;
    expected = true;
  };
}
