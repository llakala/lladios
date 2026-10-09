{ types, promise, ... }:
{
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
}
