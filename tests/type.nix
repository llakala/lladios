{ types, promise, ... }: {
  # TODO: do more generic testing of option.type promises in another file probably
  # TODO: if not already being done, do more testing of adios/types.nix types

  testType = {
    module = {
      modules.child.options.value.type = types.string;
      inputs.child.from = { self }: self.child;
      # FIXME: impl typed inputs instead, or do one version for each
      # see below tests too
      options.words = {
        type = promise ({ inputModules }: types.listOf inputModules.child.type);
      };
      result = promise (
        { options }: builtins.concatStringsSep "" (map (module: module.value) options.words)
      );
    };
    apply =
      tree:
      tree {
        words = [
          { value = "Hello"; }
          { value = ", "; }
          { value = "World!"; }
        ];
      };
    expected = "Hello, World!";
  };

  testOptionApply = {
    module = {
      modules.child.options.value.type = types.new {
        name = "string-with-space";
        verify = builtins.isString;
        apply = v: v + " ";
      };
      inputs.child.from = { self }: self.child;
      options.words.type = promise ({ inputModules }: types.listOf inputModules.child.type);
      result = promise (
        { options }: builtins.concatStringsSep "" (map (module: module.value) options.words)
      );
    };
    apply =
      tree:
      tree {
        words = [
          { value = "Hello,"; }
          { value = "World!"; }
        ];
      };
    expected = "Hello, World! ";
  };

  testResult = {
    module = {
      modules.child = {
        options.value.type = types.string;
        result = promise ({ options }: options.value + " ");
      };
      inputs.child.from = { self }: self.child;
      options.words.type = promise ({ inputModules }: types.listOf inputModules.child.type);
      result = promise ({ options }: builtins.concatStringsSep "" options.words);
    };
    apply =
      tree:
      tree {
        words = [
          { value = "Hello,"; }
          { value = "World!"; }
        ];
      };
    expected = "Hello, World! ";
  };

  testResultAndOptionApply = {
    module = {
      modules.child = {
        options.value.type = types.new {
          name = "string-with-space";
          verify = builtins.isString;
          apply = v: " " + v;
        };
        result = promise ({ options }: options.value + " ");
      };
      inputs.child.from = { self }: self.child;
      options.words.type = promise ({ inputModules }: types.listOf inputModules.child.type);
      result = promise ({ options }: builtins.concatStringsSep "" options.words);
    };
    apply =
      tree:
      tree {
        words = [
          { value = "Hello,"; }
          { value = "World!"; }
        ];
      };
    expected = " Hello,  World! ";
  };

  testOptionApplyError = {
    module = {
      modules.child.options.value.type = types.new {
        name = "string-with-space";
        # This is a lazy type, since the apply is more strict than the verify.
        verify = builtins.isString;
        apply =
          v:
          if builtins.substring 0 1 == " " then v + " " else throw "your string didn't start with a space!";
      };
      inputs.child.from = { self }: self.child;
      options.words.type = promise ({ inputModules }: types.listOf inputModules.child.type);
      result = promise (
        { options }: builtins.concatStringsSep "" (map (module: module.value) options.words)
      );
    };
    apply =
      tree:
      tree {
        words = [
          { value = "Hello,"; }
          { value = "World!"; }
        ];
      };
    expectedError.msg = "your string didn't start with a space!";
  };

  # TODO: does this actually test anything new?
  testResultAndOptionApplyError = {
    module = {
      modules.child = {
        options.value.type = types.new {
          name = "string-with-space";
          verify = builtins.isString;
          apply =
            v:
            if builtins.substring 0 1 == " " then " " + v else throw "your string didn't start with a space!";
        };
        result = promise ({ options }: options.value + " ");
      };
      inputs.child.from = { self }: self.child;
      options.words.type = promise ({ inputModules }: types.listOf inputModules.child.type);
      result = promise ({ options }: builtins.concatStringsSep "" options.words);
    };
    apply =
      tree:
      tree {
        words = [
          { value = "Hello,"; }
          { value = "World!"; }
        ];
      };
    expectedError.msg = "your string didn't start with a space!";
  };

  # TODO: test either<module1, module2>
  # testEitherFirstType = { };
  # testEitherSecondType = { };
  # testEitherInvalidValue = { };

  # TODO: test extra params error
  testExtraParams = {
    module = {
      modules.child = {
        options.value.type = types.string;
        result = promise ({ options }: options.value);
      };
      inputs.child.from = { self }: self.child;
      options.words.type = promise ({ inputModules }: types.listOf inputModules.child.type);
      result = promise ({ options }: builtins.concatStringsSep "" options.words);
    };
    apply =
      tree:
      tree {
        words = [
          {
            value = "Hello, ";
            extra = "World!";
          }
        ];
      };
    # FIXME: better error message
    # TODO: doesn't match for some reason
    # expectedError.msg = "while calling /child: tried to set nonexistent option 'extra', valid options were '[value]'";
    expectedError.type = "ThrownError";
  };

  testNotAllParams = {
    module = {
      modules.child = {
        options.value.type = types.string;
        result = promise ({ options }: options.value);
      };
      inputs.child.from = { self }: self.child;
      options.words.type = promise ({ inputModules }: types.listOf inputModules.child.type);
      result = promise ({ options }: builtins.concatStringsSep "" options.words);
    };
    # FIXME: better error message
    expectedError.msg = "attribute 'words' missing";
  };

  # TODO: test assertions
  # testLazyAssertFailure = { };
  # testLazyAssertSuccess = { };

  # TODO: test lazyness of contained types
  # testOptionTypeLaziness = { };
  # testOptionTypeLazinessStrict = { };

  # TODO: test laziness like the lazy types
}
