{ types, merge, promise, ... }:
{
  testSuccess = {
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
          merge = builtins.foldl' (acc: v: acc + v) 0;
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
        merge = merge.lists.concat;
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
    expectedError.msg = "in struct 'option': if 'mutators' are specified, 'merge' must be as well";
  };
}
