# Inputs Reference
Adios module definitions may have an `inputs` attribute within the module's attribute set. Unlike options, inputs *cannot* be overridden after the module is loaded, so consumers that want to modify the inputs of a module should use [`adios.lib.inject`](../lib/inject.md) *before* the module is loaded instead. 

`inputs` can then be used within the `defaultFunc` and `mergeFunc` of the module's options and within its `impl` function. Each input will be supplied to these functions as a loaded module, which means that you can override its options as if you were consuming the module, or leave all options to their defaults by calling it with an empty attribute set.

`inputs` is an attribute set of inputs, each of which is an attribute set containing any of the following attributes:

### From
`from` is a function that takes an attribute set containing any of the following as attributes:
- self;
    the location of this module in the tree.
- parent;
    the location of the module that import this module as a child module in the tree.
- root;
    the location of the highest module in the tree.
