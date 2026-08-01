# Adios Documentation

> [!NOTE]
> You are viewing a fork of upstream adios, known as **lladios**. Expect breaking changes, but not without proper error messages.

## What is Adios?
Adios is a general-use module system for the [nix language](https://nix.dev/). Its largest goal is to be a fast, simple, and portable alternative to the module system NixOS uses, `pkgs.lib.evalModules`, which is referred to as 'the NixOS module system' throughout this documentation.

Where you might use:

- a `pkgs.callPackage` set,
- `pkgs.lib.evalModules` for a function,
- a function with a lot of configurability (ex. `{ foo ? true, bar ? false }: ...`),

adios is able to provide a better interface with a low impact on performance.

## *Why* is adios?
The NixOS module system is a large part of why evaluating a NixOS config, even a very minimal one, takes so much time.

Adios solves a lot of the NixOS module system's issues. Here are the biggest ones along with how adios is able to solve them:

### Global Mutable Namespace
The NixOS module system uses a 'global mutable namespace.' This means any module can affect the *entire* output of the module system. Every module must be evaluated in order to get the final result, because *any* of those modules could be changing the result completely. It also offers less options when importing other modules because those imports cannot rely on *any* of the module system's state without causing an 'infinite recursion' error.

By forcing every module to specify exactly what they need as an input and only letting modules control their own outputs, adios keeps the importing of modules a lazy process.

### Resource Overhead
Because of its non-lazy importing of modules, the NixOS module system takes more and more time to evaluate for every module that is added. At the scale of NixOS, this results in slow evaluation and high resource usage; it can be impossible to evaluate even a very minimal config on a machine with few resources. The same applies for everything else that uses this module system: Home-manager, for example, increases evaluation resource usage and time by just being imported, even if you don't use it at all in your configuration.

Adios takes full advantage of nix's laziness and optimizes for memoisation, making it scale much better at high module counts and where many modules go unused.

### Error Messages
Error messages from `evalModules` lack the context needed to be relevant and usable. Instead of being helpful, they are (somewhat infamously) difficult to parse, especially for users new to nix. Adios' errors are simple, clear, and readable, and give you the information needed to fix what's breaking.

### Portability
Because NixOS modules rely on every other module in order to work (and in an undeclared fashion), they aren't reusable outside of a NixOS context. Adios modules depend only on what they need and are applicable across many situations; that's what makes them 'modular' in the first place.
