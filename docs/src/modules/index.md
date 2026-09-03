# Adios Modules

## Definitions

Adios module definitions are simply nix attribute sets.
```nix
let
  # This is an impure solution and not recommended for actual usage.
  # Look at the installation guide for proper instructions.
  adios = import (fetchTarball "https://github.com/llakala/lladios/archive/main.tar.gz");
in {
  options.name = {
    type = adios.types.string;
    default = "Alice";
  };

  impl = { options }: "Hello, ${options.name}!";
}
```

In order to use modules, their definitions have to be *loaded* by the adios loader function (provided as a functor
within the `adios` attribute set). This loader function supplies the module with its inputs, type checks its options,
and, if an `impl` is present in the module, makes it *callable* by adding a functor to it.
```nix
let
  # This is an impure solution and not recommended for actual usage.
  # Look at the installation guide for proper instructions.
  adios = import (fetchTarball "https://github.com/llakala/lladios/archive/main.tar.gz");

  module = {
    options.name = {
      type = adios.types.string;
      default = "Alice";
    };

    impl = { options }: "Hello, ${options.name}!";
  };

  loadedModule = adios module {};
in
  loadedModule {
    name = "Bob";
  } # -> "Hello, Bob!"
```

## Inputs and Child Modules
Adios module definitions can contain a `modules` attribute. `modules` is an attribute set of other adios modules, which
can set `modules` of their own, and so on, creating a *tree* of modules. A simple way to set this without inlining other
modules is by using [`adios.lib.importModules`](../lib/importModules.md).

Once a tree of modules is established, you can add other modules as *inputs* to the module you're working in. Within a
module definition, `inputs` is an attribute set of input definitions (full reference [here](./inputs.md)). Each input
definition can provide a `from` function that points to another module, based on the other module's position in the
tree. Then, the first module's `impl` function will have access to the new module, *after* it is loaded.
```nix
let
  # This is an impure solution and not recommended for actual usage.
  # Look at the installation guide for proper instructions.
  adios = import (fetchTarball "https://github.com/llakala/lladios/archive/main.tar.gz");

  root = {
    modules = {
      hello = {
        options.name = {
          type = adios.types.string;
          default = "Alice";
        };

        impl = { options }: "Hello, ${options.name}!";
      };

      helloAndWelcome = {
        inputs.hello.from = { parent }: parent.hello;

        options.name = {
          type = adios.types.string;
          default = "Alice";
        };

        impl = { inputs, options }: (inputs.hello { inherit (options) name; }) + " Welcome!";
      };
    };
  };

  loadedModule = adios root {};
in
  loadedModule.modules.helloAndWelcome {
    name = "Bob";
  } # -> "Hello, Bob! Welcome!"
```

## Conventions
While inline module definitions as shown in the above examples work, modules are more commonly expressed as functions
that take the `adios` attribute set and *return* a module, allowing the module definition to be contained in one file,
and then imported with `import ./file.nix adios`. This convention is supported by
[`adios.lib.importModules`](../lib/importModules.md).
```nix
adios: {
  options.name = {
    type = adios.types.string;
    default = "Alice";
  };

  impl = { options }: "Hello, ${options.name}!";
}
```
