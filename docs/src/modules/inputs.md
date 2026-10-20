# Module Inputs

The `inputs` attribute is an attribute set of inputs, each of which is an attribute set in the following format:

```nix
{
  inputs.<name>.from = { <origin> }: <origin>.<attribute>;
}
```

where `<origin>` can be either:

- `root` - the location of the highest module in the tree.
- `parent` - the location of the module that import this module as a child module in the tree.
- `self` - the location of this module in the tree.

and the attribute is optional.

You can then select modules of the origin, modules of the origin's modules, and so on, by accessing attributes:

```nix
{
  inputs.bar.from = { parent }: parent.foo.bar;
}
```

The above example will resolve to the child module 'bar' from the current module's sibling 'foo'.

`inputs` can then be used within promises and `mergeFunc`s of the module's `options` and `result`. Each input provided
this way will be an attribute set of all of the options the user has set for that input.

## Adding arguments

However, you will frequently want to access the *output* of an input module, rather than just its options. To do so, you can
*call* the input module by specifying the options to call it with (`inputs.<input>.options`). These 
The input can then be accessed within the `results` argument to promises.

```nix
{
  inputs.square = {
    from = { root }: root.square;
    options = { number = 2; };
  };
  
  result = adios.promise ({ results }: results.square + 3; )
}
```
