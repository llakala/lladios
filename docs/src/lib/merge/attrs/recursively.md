# `merge.attrs.recursively`

## Behavior

This function takes the raw data from mutators each providing some attribute set, like this:

```nix
{
  "/foo" = {
    nested.a = "demo";
  };
  "/bar" = {
    nested.b = 2;
  };
  "/baz" = {
    nested.doubleNested.c = null;
    onlyUsedOnce = true;
  };
}
```

And merges the values into:

```nix
{
  nested = {
    a = "demo";
    b = 2;
    doubleNested = {
      c = null;
    };
  };
  onlyUsedOnce = true;
}
```

## Usage

This function should only be used if you want:

1. The option in question to be mutated by other modules
1. Attrsets with identical keys to be merged recursively
1. Other values with identical keys to throw an error

For example:

```nix
# modules/git.nix
{ adios }:
let
  inherit (adios) types;
in
{
  options = {
    settings = {
      type = types.attrs;
      mutatorType = types.attrs;
      mergeFunc = adios.lib.merge.attrs.recursively;
    };
  };
}
```
