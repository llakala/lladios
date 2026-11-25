{ types, promise, await, ... }@adios:
{
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

  testMappingNonPromise = {
    module = adios.lib.inject [
      {
        options.test = {
          type = types.int;
          default = 10;
        };
        result = promise ({ options }: options.test);
      }
      {
        options.test.default = await (prev: prev + 1);
      }
    ];
    expected = 11;
  };

  testMappingPromise = {
    module = adios.lib.inject [
      {
        options.hello = {
          type = types.string;
          default = "hello";
        };
        result = promise ({ options }: options.hello);
      }
      {
        result = await (prev: prev + " world");
      }
    ];
    expected = "hello world";
  };

  testSubPromise = {
    module = adios.lib.inject [
      {
        result = promise (_: 2);
      }
      {
        options.foo = {
          type = types.int;
          default = 5;
        };
        result = await (
          prev:
          # return a new promise
          promise ({ options }: prev + options.foo)
        );
      }
      {
        result = await (prev: prev - 7);
      }
    ];
    expected = 0;
  };
}
