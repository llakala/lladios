{ merge, ... }:
{
  testSuccess = {
    expr = merge.attrs.recursively [
      { foo.bar = 1; }
      { foo.baz = 2; }
    ];
    expected = {
      foo.bar = 1;
      foo.baz = 2;
    };
  };

  testFailure = {
    expr = merge.attrs.recursively [
      { foo.bar = 1; }
      { foo.bar = 2; }
    ];
    expectedError.msg = ''
      while calling 'adios.merge.attrs.recursively':
      while attempting to merge mutators \[
        \{ foo = \{ bar = 1; }; }
        \{ foo = \{ bar = 2; }; }
      ]
      found key 'bar' set to multiple values that couldn't be merged
      unmergeable values: \[ 1 2 ]'';
  };
}
