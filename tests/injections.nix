{ types, promise, ... }@adios:
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

  testPromiseMappingNonPromise = {
    module = adios.lib.inject [
      {
        options.test = {
          type = types.int;
          default = 10;
        };
        result = promise ({ options }: options.test);
      }
      {
        options.test.default = promise.map (prev: prev + 1);
      }
    ];
    expected = 11;
  };

  testPromiseMappingPromise = {
    module = adios.lib.inject [
      {
        options.hello = {
          type = types.string;
          default = "hello";
        };
        result = promise ({ options }: options.hello);
      }
      {
        result = promise.map (prev: prev + " world");
      }
    ];
    expected = "hello world";
  };

  testTriplePromise = {
    module = adios.lib.inject [
      {
        result = promise (_: 2);
      }
      {
        result = promise.map (prev: prev * 3);
      }
      {
        result = promise.map (prev: prev + 1);
      }
    ];
    expected = 7;
  };
}
