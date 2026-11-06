# Adios Modules

An Adios module definition is an attribute set. Module definitions care about any of the following attributes:

- [`options`](./options.md) - what users of the module are able to modify.
- [`inputs`](./inputs.md) - the modules this module depends on.
- [`result`](./result.md) - declares the value to be returned when evaluating the module.
- [`modules`](./child-modules.md) - child modules of this module.
- [`mutations`](./mutations.md) - how this module is able to modify other modules.
- [`assertions`](./assertions.md) - statements that this module declares must be true.

Any other attributes may also be present (other than `__functor`), and Adios will ignore them during evaluation. A few
conventions:

- `meta` - additional information about the module.
- `tests` - declarations that verify that the module is working properly.

## Declaring Modules

A module definition can be declared inline like so:

```nix
let
  module = {
    options.some-option.type = adios.types.int;
    result = adios.promise ({ options }: options.some-option);
    modules.some-child = {
      result = null;
    };
  };
in
# evaluate the module with adios (see the next section)
```

However, this doesn't scale very well, and requires a lot of `adios.$foo`. For this reason, Adios provides a convenience
function to load a set of modules from some directory.

```nix
let
  # root module that defines some set of children
  root = {
    modules = adios.lib.importModules { directory = ./modules; };
  };
in
# ...
```

See the documentation on [importModules](../lib/importModules.md). Most examples will be given with the assumption that
`importModules` is used.

## Loading Modules

Once module(s) are defined, they can be _evaluated_ by Adios by using the `adios` functor.

For a single module:
```nix
let
  module = ...;
  evaluatedModule = adios module {};
in
# returns the module to be called
module
```

Or for a set of modules:
```nix
let
  root = ...;
  tree = adios root {};
in
# returns a set of callable modules
tree.modules
```

## Calling Modules

After a module is evaluated, it can be *called* by supplying it with an attribute set.

For a single module:
```nix
let
  module = ...;
  evaluatedModule = adios module {};
in
module { some-option = 1; }
```

For a set of modules:
```nix
let
  root = ...;
  tree = adios root {};
in
tree.modules.some-module { some-option = 1; }
```
