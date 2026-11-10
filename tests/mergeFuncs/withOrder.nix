{ merge, ... }:
{
  testSuccess = {
    expr = merge.general.withOrder merge.lists.concat [
      {
        value = [ "hello" ];
        order = 1;
      }
      {
        value = [ "world" ];
        order = 2;
      }
    ];
    expected = [
      "hello"
      "world"
    ];
  };
}
