Any new features or breaking changes will be listed here.

# New typedef function

`typedef` and `typedef'` have been deprecated in favor of `types.new`, which uses structured attributes and combines
the usecases of both functions. This is for UX purposes and clarity, as an apostrophe suffix is difficult to notice.

`types.new` takes a `name` string and a `verify` function, which returns `union<true,false,string>`. True represents a
passing typecheck, while false represents a failing typecheck, and a string represents a failing typecheck with a custom
error message. This replaces the usecases of both `typedef` and `typedef'`.

`types.typedef` usage should be replaced as such:

```nix
# old
types.typedef "two" (v: v == 2)
# new
types.new {
  name = "two";
  verify = v: v == 2;
}
```
While `types.typedef'` usage should be replaced as such:
```nix
# old
types.typedef' "two" (v: if v == 2 then null else "v was not equal to 2")
# new
types.new {
  name = "two";
  verify = v: if v == 2 then true else "v was not equal to 2";
}
```

Along with this, the exposed `verify` function of a type has had its signature changed from `union<null,string>` to
`union<true,string>`. Note that unlike the `verify` function passed to `types.new`, this will never return false, so it
doesn't have to be handled.

Polymorphic types should be modified as such:
```nix
# old
t: types.typedef' "polymorphic<${t.name}>" (if t.verify v == null then null else "some error message")
# new
t: types.new {
  name = "polymorphic";
  verify = v: if t.verify v == true then true else "some error message";
}
```

# Improved error formatting and messages

Adios now uses Nix logic for handling error context, instead of passing around context manually with strings. This
allows us to provide much more info in the stack trace, and makes errors much more readable by splitting them into
multiple lines.

Before, an Adios error trace would look like this:
```
    error: while computing '/less' args: in option 'configFile': type error: Expected type 'pathLike' but value '5' failed the type check
```

Now, it looks like this:
```
    … while calling '/mkWrapper': in option 'symlinks'

    … in '/fish': in option 'interactiveShellInit'

    … in '/fish': in mutator '/starship' of option 'interactiveShellInit'

    … while calling '/mkWrapper': in option 'symlinks'

    … while calling '/mkWrapper': in option 'environment'

    … in '/less': in option 'configFile'

    (stack trace truncated; use '--show-trace' to show the full, detailed trace)

    error: Expected type 'pathLike' but value '5' failed the type check
```

This is hopefully the start of improved error messaging from Adios. Some information is still not printed, and ideally
the position of the error would be displayed (although this may be more difficult than it appears, due to position
information being lost on certain builtins).

Note that on Lix, the full error trace may not be visible without `--show-trace`.

# Improved check function

The `check` function produced by the Adios type system has a new signature. Previously, `check` would take two valuse:
the value to be typechecked, and the value that should be returned on success. On failure, it would throw. However, this
wasn't very useful, as checks typically just want to return the value on success.

The `check` function now only takes the value itself, which will be returned on success, instead of a customizable
default. In the future, Adios options may support `apply` semantics, to better support the usecase of the previous
signature.

A change like this would typically be done with a warning first, but `check` is an internal field of the type system
that makes no stability guarantees, so anyone relying on the old signature will get an error.

# First-class injections

`adios.lib.inject` has been added, and is now recommended over `lib.recursiveUpdate` for injections.

Previous usage of this form:

```nix
root = {
  modules = lib.recursiveUpdate base (
    adios.lib.importModules { directory = ./modules; }
  );
};
```

Should be replaced with:

```nix
root = {
  modules = adios.lib.inject [
    base
    (adios.lib.importModules { directory = ./modules; })
  ];
};
```

`adios.lib.inject` is more optimized than `lib.recursiveUpdate`, and also offers additional functionality, where a
module can read its "old" version before returning the injection. For more info, see [the
docs](./doc/src/lib/inject/index.md).

# Structured `importModules`

Calling `adios.lib.importModules` with a path directly has been deprecated in favor of:
```nix
root = {
  modules = adios.lib.importModules {
    directory = ./modules;
  };
}
```

This is to allow greater extensibility. `importModules` passes the Adios attrset to every single file, but this value
for Adios is passed internally. This makes it impossible to add custom `lib` and `types` functions without importing the
importModules file directly (which is very hacky).

With the new form, you can change the args directly:

```nix
modules = adios.lib.importModules {
  directory = ./modules;
  # if not set, args defaults to the internally-passed adios
  args = adios // {
    types = adios.types // {
      inherit customType;
    };
    lib = adios.lib // {
      inherit customFunction;
    };
  };
};
```

# Input references

Input paths have been deprecated in favor of input _references_. Previously, the location of an input in the tree was
specified with a path-like syntax:

```nix
inputs = {
  foo.path = "/foo"; # absolute path from root module
  bar.path = "../bar"; # sibling of current module
  baz.path = "./baz"; # child of current module
};
```

However, this was often a source of confusion for new users, because the path wasn't actually a filesystem path, even
though it appeared as such. Relative paths also were confusing to use, as the current module acted more like a folder
than a file, meaning `../sibling` was correct, not `./sibling`.

The new semantics look like this:

```nix
inputs = {
  foo.from = { root }: root.foo; # equivalent of absolute path
  bar.from = { parent }: parent.bar; # sibling of current module
  baz.from = { self }: self.baz; # child of current module
};
```

The new semantics also allow going down multiple levels:

```nix
inputs = {
  child-of-foo.from = { root }: root.foo.child-of-foo;
  niece.from = { parent }: parent.sibling.niece;
  grandchild.from = { self }: self.child.grandchild;
};
```

These new semantics are technically less powerful than the old version, as you can no longer fetch an "uncle module"
without referring to root. This is by design - references to `parent`, `self`, and `root` accomodate 90% of usecases
while keeping the API simple for new users. If a module set needs references to "uncle modules" that don't refer to
root, the module set's structure should likely be refactored.

# Mutators as lists

When writing a mergeFunc, `mutators` is now a list of values, instead of an attrset. This previously allowed checking
the name of an attribute to special-case mutations from certain paths, but this was never used from my knowledge, and
required constantly using `attrValues` inside mergeFuncs to ignore the names.

# `withPrio` renamed

`adios.lib.merge.general.withPrio` has been renamed to `adios.lib.merge.general.withOrder`, and now sorts based on the
numeric value of `order =` instead of `priority =`. This is because we don't currently have a polymorphic merge function
that only allows unique definitions, and I'd like to avoid a naming collision on this in the future.

# `types.nullOr` renamed

`types.optional` has been renamed to `types.nullOr`, and now warns on usage. While optional has a specific meaning in
languages with sum types, it's often used in other ways in a nix context (see optionalString, optionalAttrs, optionals,
etc). To clarify the purpose of the type, it's been renamed.

# Faster typechecks

Adios modules now avoid unnecessary attrset merges when typechecking. To prevent visual noise, some attributes are only
included in the typechecked module if they're actually defined. To accomplish this, `optionalAttrs` was used previously:

```nix
final = {
  options = typeCheck (def.options or {});
  inputs = typeCheck (def.inputs or {});
} // optionalAttrs (def ? types) {
  types = typeCheck def.types;
} // optionalAttrs (def ? lib) {
  lib = typeCheck def.lib;
} // optionalAttrs (def ? impl) {
  impl = typeCheck def.impl;
}
```

However, it's actually possible to avoid this, by using null attribute names.

```nix
final = {
  options = typeCheck (def.options or {});
  inputs = typeCheck (def.inputs or {});
  ${if def ? types then "types" else null} = typeCheck def.types;
  ${if def ? lib then "lib" else null} = typeCheck def.lib;
  ${if def ? impl then "impl" else null} = typeCheck def.impl;
}
```

Nix automatically filters out any null names, so this accomplishes the same behavior without 3 attrset merges. On my
end, this saves \~5kb of memory, \~150 function calls, and \~170 thunks.

# No eval stage

The eval stage is now removed on a technical level.

Previously, Adios had a lot of infrastructure that created a closure for all the modules needed in the eval stage.
This was meant to provide fast lookups for these results that could be used across the tree. However, this came with a
lot of complexity that leads to niche issues.

While trying to fix a bug related to the eval stage not handing `impl`s properly, I tried stripping out the eval stage
logic. Without it, evaluation speed actually improved. It may be possible that the eval stage improves performance in
some contrived cases. But generally, the closure idea doesn't really make sense when we're already lazily looking up
args.

Do note that the eval stage means something different on a technical and user/facing level. Calling `adios root {
options."/nixpkgs".pkgs = pkgs; }` still works. The only thing that's removed is the internal logic, where
args were previously queried from the eval closure before computing them normally.

This shouldn't affect anything on the user side - although I expect it to fix a few niche bugs. If you experience any
regressions, please make a bug report.

# Nested options fix

Nested options under `options.foo.options.bar` should now work correctly with mutators.

# Improved path messages

When first typechecking a module, we now immediately store its path as an accessible attribute. This should improve a
few niche error cases, so the module to blame is always reported.

# `types.option` renamed

`types.option` has been renamed to `types.optional`. The word option already has a meaning in an Adios context, so
preventing a naming collision is preferable.

# Type mismatch error improved

The error message when a type fails to match has been improved. Previously, Adios would print type errors in this
format:

```
Expected type '${type.name}' but value '${value}' is of type '${typeOf value}'
```

However, the result of `typeOf value` simply prints the primitive Nix type. This had several issues.
1. `typeOf` doesn't handle derivations properly, and just prints `set`.
2. It made errors for non-trivial types more confusing. For example, if a struct failed to match, Adios would print
   `but value ${value} is of type 'set'`, but structs _are_ sets. Printing the primitive type isn't very useful in
   most cases.

The error message format has been changed to:
```
Expected type '${name}' but value '${toPretty v}' failed the type check
```

This clarifies that Adios doesn't really know what type the input data was - it just knows the verification function
returned false. The primitive type is no longer printed, as it seems to do more harm than good in this context.

# Internal type definitions refactored

Adios typechecks modules, so `options = []` throws an error. Several of these type definitions have been refactored.
This shouldn't cause a change in behavior, so please report if you experience any differences.

# Improved `attrsOf` error messages

Error messages generated by the `attrsOf` type have been improved, to now point to the exact attribute causing the
error. Previously, a type of `types.attrsOf types.string` being applied to `{ x = 1; y = "demo"; }` would return an
error message that didn't specify the key causing the error:

```
in attrsOf<string> value: Expected type 'string' but value '1' is of type 'int'
```

Now, it will return:

```
in attrsOf<string> value: in attribute 'x': Expected type 'string' but value '1' is of type 'int'
```

# Submodules fixed

Basic submodule support is now fixed. This originates back to the original commit of adios - and it's so old and
unused that I didn't understand it until I looked at the old tests. But Adios actually supports "sub-options":
```nix
{ types, ... }:
{
  options.foo = {
    options.bar = {
      type = types.string;
      default = "demo";
    };
  };

  impl = { options }: options.foo.bar;
}
```
For most cases, I recommend sticking with structs over sub-options. However, a module providing a complex API
underneath some attribute may benefit from this. Submodule support is something I hope to improve in the future, so
an option can point to the full API of some input module.

# `types.str` removed

`types.str`, an alias for `types.string`, has been removed. I don't think this is a necessary alias, and I'd prefer to
see everyone congregate on the string form.

# Korora moved internally

The internal path of korora (the Adios type system) has been changed. Uses of `${sources.adios}/types/types.nix`
should be changed to `${sources.adios}/korora`. This is very unlikely to affect you, unless you're vendoring korora
specifically from Adios.

# Default `unknown` to false

The value of `unknown` for structs now defaults to false. This means that structs will reject any field that they
don't specify. To achieve the old behavior, the struct can be overridden:

```nix
(types.struct "structName" {
  foo = types.int;
  bar = types.string;
}).override { unknown = true; }
```

# Ignore name field

The `name` parameter of Adios modules now does absolutely nothing. Originally, names actually had a semantic meaning.
This has been removed for a long time, but names still slightly improved the state of error logging. Now, they do
nothing, and won't be included at all when loading a module.

# No overriding a tree

`(adios root {}).override` has been removed. I've never seen anyone actually use this, and I'm generally unsure about
some of the design decisions of the eval stage.

# Import adios directly

`adios = (import sources.adios).adios` boilerplate is no longer required. Instead, one can just do `adios = import
sources.adios`. This comes along with the removal of the `contrib/` modules. The old entrypoint now provides a
warning.

# Add mutators

An opt-in mutation API has been introduced, which let one module set another module's option via user-defined merge
semantics.

# Call input directly

Modules are now able to call another's `impl` via `inputs.foo {}`.

# Call own impl directly

A module can now call its own `impl` via `options {}`.
