{ merge, ... }:
{
  testSuccess = {
    expr = merge.attrs.flat [
      { a = 1; }
      { b = 2; }
      { c.d = 3; }
    ];
    expected = {
      a = 1;
      b = 2;
      c.d = 3;
    };
  };

  # the toplevel keys must be disjoint
  testFailure = {
    expr = merge.attrs.flat [
      { foo.bar = 1; }
      { foo.baz = 2; }
    ];
    expectedError.msg = ''
      while calling 'adios.merge.attrs.flat':
      while attempting to merge definitions '\[
        \{ foo = \{ bar = 1; }; }
        \{ foo = \{ baz = 2; }; }
      ]':
      found multiple definitions attempting to set key 'foo''\''';
  };
}
