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

## Example

Here's an example of injecting into a basic Adios module:

```nix
let
  base = {
    options = {
      age = {
        type = types.int;
        default = 10;
      };
      age-someday = {
        type = types.int;
        default = promise ({ options }: options.age + 1);
      };
    };

    impl = { options }: ''
      You are ${toString options.age} years old.
      Someday, you will be ${toString options.age-someday} years old.
    '';
  };


  injection = {
    options = {
      age.default = 35;
      age-someday.type = types.float;
      age-someday.default = promise ({ options }: options.age + 0.1);
    };
  };

  module = adios.lib.inject [ base injection ];
  tree = adios module {};
in
tree {} == ''
  You are 35 years old.
  Someday, you will be 35.1 years old.
''
```

## Using promises

`promise.map` can be used inside injections to "await" the old version of an attribute. Here's an alternative injection
for the above module that makes use of it:

```nix
let
  injection = {
    options.age.default = promise.map (prev: prev * 2);
    options.age-someday.type = types.string;
    options.age-someday.default = promise.map (prev: "ABOUT " + toString prev);
  };

  module = adios.lib.inject [ base injection ];
  tree = adios module {};
in
tree {} == ''
  You are 20 years old.
  Someday, you will be ABOUT 21 years old.
''
```

Let's take a look at how this works. When `adios.lib.inject` is called, `options.age.default` was _not_ a promise -- so
the `prev:` function can be resolved immediately, and `20` is returned. But `age-someday` is more interesting. Since the
original value was a promise, we don't know what `prev` is until the original promise is resolved. So `promise.map`
instead returns a _new_ promise that wraps the original promise. Upon evaluating the injected module with Adios, the
promises will be resolved recursively.
