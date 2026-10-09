{ types, promise, ... }:
{
  testSuccess = {
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
}
