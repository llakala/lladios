{ types, promise, ... }:
{
  testSuccess = {
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
}
