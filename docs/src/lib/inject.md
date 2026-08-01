# `inject`

`adios.lib.inject` allows applying changes to a module tree recursively.

## Usage

A typical call to `inject` will look something like this:

```nix
let
  root = {
    modules = adios.lib.inject [
      # base set of modules, likely fetched from an external source
      base

      # folder containing a set of module injections
      # if the base set contains some module foo, then modules/foo.nix will inject into the foo module
      # if it DOESN'T contain some module foo, modules/foo.nix just creates a new module
      (adios.lib.importModules { directory = ./modules; })
    ];
  };

  tree = adios root {};
in
  tree.modules
```

Note that `inject` takes a list for a reason - injections can be performed multiple times. This works as you may expect,
where each set injects into the previous one from left to right.
```nix
  root = {
    modules = adios.lib.inject [
      fetchedSet1
      fetchedSet2
      (adios.lib.importModules { directory = ./modules; })
    ];
  };
```

## How does it work?

`inject` can be thought of as "recursive `//`" for module definitions. If you're not familiar with the
intricacies of `//`, it works like this on attribute sets:

```nix
{ a.b = 1; } // { a.c = 2; }
# =>
{ a.c = 2; }
```

`inject` makes this behavior work recursively.

```nix
adios.lib.inject [ { a.b = 1; } { a.c = 2; } ]
# =>
{ a = { b = 1; c = 2; }; }
```

Just like `//`, it also allows overriding an existing attribute's value.

```nix
adios.lib.inject [
  { unchanged-value = true; nested.overridden-value = -1; }
  { nested.overridden-value = true; }
]
# =>
{ unchanged-value = true; nested.overridden-value = true; }
```

## Simple example

Here's an example of injecting into a basic Adios module:

```nix
let
  module = {
    options = {
      age = {
        type = types.int;
        default = 10;
      };
      age-someday = {
        type = types.int;
        defaultFunc = { options }: options.age + 1;
      };
    };

    impl = { options }: ''
      You are ${toString options.age} years old.
      Someday, you will be ${toString options.age-someday} years old.
    '';
  };


  injections = {
    options = {
      age.default = 35;
      age-someday.type = types.float;
      age-someday.defaultFunc = { options }: options.age + 0.1;
    };
  };

  root = {
    modules = adios.lib.inject [
      { age-module = module; }
      { age-module = injections; }
    ];
  };
  tree = adios root {};
in
(tree.modules.age-module {}) == ''
  You are 35 years old.
  Someday, you will be 35.1 years old.
''
```

## Advanced example

Injections also support an advanced form, where they take the old version of the module as a parameter. With the module
from the simple example, that might look like:

```nix
let
  module = {
    options = {
      age = {
        type = types.int;
        default = 10;
      };
      age-someday = {
        type = types.int;
        defaultFunc = { options }: options.age + 1;
      };
    };

    impl = { options }: ''
      You are ${toString options.age} years old.
      Someday, you will be ${toString options.age-someday} years old.
    '';
  };

  newModule = old: {
    # default of 10 multiplied by 2
    options.foo.default = old.options.foo.default * 2;
  };

  injection = {
    modules = adios.lib.inject [
      { age-module = module; }
      { age-module = injection; }
    ];
  };
  tree = adios root {};
in
(tree.modules.age-module {}) == ''
  You are 20 years old.
  Someday, you will be 21 years old.
''
```

There are some quirks of this that should be noted.

1. It only works if each element is a _set_ of modules, not a module itself.
```nix
# this doesn't work with the advanced form
adios.lib.inject [
  module
  injection
]

# this works
adios.lib.inject [
  { module = module; }
  { module = injection; }
]
```

2. It works recursively.
```nix
# this works
adios.lib.inject [
  { foo.modules.bar = module; }
  { foo.modules.bar = injection; }
]
```

3. As this behavior is specific to Adios module sets, it's recommended to use `lib.recursiveUpdate` for generic attrset updates.
