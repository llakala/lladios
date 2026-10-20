# Adios Modules

An adios module definition is an attribute set. Module definitions care about any of the following attributes:

- [`options`](./options.md) - what users of the module are able to modify.
- [`result`](./result.md) - how the module transforms the options and inputs into the end result.
- [`modules`](./child-modules.md) - child modules of this module. Determines the way `inputs` are threaded.
- [`inputs`](./inputs.md) - the modules this module depends on.
- [`mutations`](./mutations.md) - how this module is able to modify other modules.
- [`assertions`](./assertions.md) - statements that this module declares must be true.

Any other attributes may also be present (other than `__functor`), and adios will ignore them. A few conventions:

- `name` - the title of the module. in older versions of adios, this was significant; that is no longer the case.
- `meta` - additional information about the module.
- `tests` - declarations that verify that the module is working properly.

## Loading Modules

Once a module definition is established, it can be converted into a *loaded* module by using the `adios` functor:

```nix
adios {
  options = {
    foo = {
      type = adios.types.string;
      default = "World";
    };
  };
  
  result = promise ({ options }: "Hello ${location}!")
} {}
# -> a loaded module
```

## Calling Modules

After a module is loaded, it can be *called* by supplying it with an attribute set.

```nix
let
  module = adios {
    options = {
      foo = {
        type = adios.types.string;
        default = "World";
      };
    };
    
    result = promise ({ options }: "Hello ${location}!")
  } {};
in
  module { location = "Universe"; }
# -> "Hello Universe!"
```
