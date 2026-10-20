# Adios Documentation

> [!NOTE]
> This documentation goes over the syntax and structure of *lladios*, a fork of adisbladis' adios module system. It
> implements more features such as mutators and promises that improve the flexibility and syntax of adios. lladios is
> still called adios because it's intended to be a continuation of adios.

## What is Adios?

Adios is a general-use module system for the [nix language](https://nix.dev/). Its goal is to be a fast, simple, and
portable alternative to `lib.evalModules` (the module system used by NixOS and home-manager). `lib.evalModules` may be
referred to as 'the NixOS module system' throughout this documentation.

Where you might use:

- a function with a lot of configurability (ex. `{ foo ? true, bar ? false }: ...`)
- a `pkgs.callPackage` set
- A small/medium `lib.evalModules` set

Adios aims to be a powerful alternative with minimal performance overhead.

## *Why* is `lib.evalModules` slow?

`lib.evalModules` is very simple at a high level. Given a set of modules, each module can set any other module's
options, thereby mutating it. This is a 'global mutable namespace' - and it's a terrible idea for performance.

Let's look at the `environment.systemPackages` option. To determine the value of this option, we must:

1. Find all the places where this option is mutated
2. Merge each definition together

But how do we find those locations? Well, it's simple - we just have to iterate through every other module. But this
means a module set scales with the number of modules in the set - _not_ the number of modules you actually use.

At first, it looks like "enable options" solve this - just only evaluate a module if it's enabled! But enable options
are just a common practice, and not enforced by the module system. The whole point of a global mutable namespace is that
modules can mutate whenever they want. If we want something better, we'll have to change our model.

## Why is Adios fast?

Adios has a completely different model. Rather than working like `lib.evalModules`, where you have a bunch of modules
that define options and mutate _other_ options, each Adios module is more like a function. Declare some options for the
module, "call" the module, and get some kind of output.

Here's an example of an Adios module in *function form*:

```nix
{ promise, types, ... }: 
{
  options = {
    num1 = {
      type = types.int;
      default = 10;
    };
    num2 = {
      type = types.int;
    };
  };

  result = promise ({ options }: options.num1 + options.num2);
}
```

If we "call" this module:
```nix
module { num2 = 3; }
```

Then it provides `13` as an output.

See the reference pages for more information. In the future, adios will have a guide that walks through building an adios module set. Feel free to contribute it!
