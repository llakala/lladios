adios: {
  testSuccess = {
    expr = adios.lib.merge.attrs.flat {
      mutators = [
        { a = 1; }
        { b = 2; }
        { c.d = 3; }
      ];
    };
    expected = {
      a = 1;
      b = 2;
      c.d = 3;
    };
  };

  # the toplevel keys must be disjoint
  testFailure = {
    expr = adios.lib.merge.attrs.flat {
      mutators = [
        { foo.bar = 1; }
        { foo.baz = 2; }
      ];
    };
    expectedError.msg = ''
      while calling 'adios.lib.merge.attrs.flat':
      while attempting to merge mutators '\[
        \{ foo = \{ bar = 1; }; }
        \{ foo = \{ baz = 2; }; }
      ]':
      found multiple mutators attempting to set key 'foo''\''';
  };
}
