# Child Modules

The `modules` attribute is a list of adios module definitions.

```nix
{
  modules.<module-name> = {
    options.foo = {
      type = adios.types.string;
      default = "bar";
    };
  };
}
```

The structure of `modules` determines how [`inputs`](./inputs.md) are threaded.
The first module in the tree will be the `root` module. It can be accessed as `root` within inputs.
Each child of root can be accessed using it's module name (as shown in the above codeblock).
For example, `root.foo.bar` will use the module `root.modules.foo.modules.bar`.
