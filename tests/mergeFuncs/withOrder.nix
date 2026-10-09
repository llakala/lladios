adios: {
  testSuccess = {
    expr = adios.lib.merge.general.withOrder adios.lib.merge.lists.concat {
      mutators = [
        {
          value = [ "hello" ];
          order = 1;
        }
        {
          value = [ "world" ];
          order = 2;
        }
      ];
    };
    expected = [
      "hello"
      "world"
    ];
  };
}
