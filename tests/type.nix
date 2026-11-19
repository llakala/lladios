{ types, promise, ... }: {
  # TODO: test either<module1, module2> (once the fixme in loadTree is resolved)
  # TODO: test laziness like the lazy types
  # TODO: test module.type of modules with a result
  # TODO: maybe elsewhere, but should also do more generic testing of option.type promises

  testModuleType = {
    module = {
      modules.child = {
        options.value.type = types.string;
      };

      inputs.child.from = { self }: self.child;

      options.words = {
        # FIXME: impl typed inputs instead, or do one version for each
        type = promise ({ inputModules }: types.listOf inputModules.child.type);
      };

      # TODO: concatStrings?
      result = promise (
        { options }: builtins.foldl' (acc: next: acc + next) "" (map (module: module.value) options.words)
      );
    };

    evalParams = {
      options."/".words = [
        { value = "Hello"; }
        { value = ", "; }
        { value = "World!"; }
      ];
    };
    expected = "Hello, World!";
  };
}
