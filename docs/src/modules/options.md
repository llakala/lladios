# Module Options

The `options` attribute defines a set of multiple options. Each option is an attribute set in the following format:

```nix
{ types, ... }:
{
  options.some-option = {
    # Required attributes
    type = types.<type>;

    # Optional attributes (for documentation)
    default = "default value";
    description = "description of the option";
    example = "something the option could be set to";

    # For mutable options only
    mergeFunc = { mutators }: head mutators;
    mutators = [ "/path/to/mutator" "/some/other/mutator" ];

    # For submodules only
    options.some-sub-option.type = types.int;
  };
}
```

## Setting options

When a user calls the loaded module, each of the options may be overriden.

```nix
tree.modules.some-module {
  some-option = 25; # this overrides the default (if it exists)
}
```

A custom value may also be set via an [injection](./injections.md) that sets/modifies the default.

```nix
# injections/foo.md
{
  options.some-option.default = ./some-file.toml; # our desired value for the option
}
```

## Laziness

Options are evaluated _lazily_. If an option is set by the user, but never read by the module, its value will never be
evaluated. Here's an example:

```nix
{ types, promise }:
{
  options = {
    used-option = {
      type = types.int;
      default = 1;
    };
    unused-option = {
      type = types.string;
      default = 5; # this fails the typecheck, but it's never read by `result` - so no error
    };
  };

  result = promise (
    { options }:
    options.used-option
  );
}
```

## Attributes

### `type`

The type of the option, defined with Adios's type system. If the typecheck of an option fails to pass, an error will be
thrown.

All options must specify this (except in the edge case of sub-options).

### `default`

The default value of the option, if the user doesn't specify a value. The default may be a [promise](./promise.md).

### `description`

A description of the option, for reference and documentation generation.

### `example`

An example of a potential value, for reference and documentation generation. This is untyped, to allow for "faking" an
example.

```nix
{
  options.some-option = {
    type = types.attrsOf types.derivation;
    example = ''
    {
      foo = pkgs.git; # can pretend that pkgs is in scope, and write comments!
    }'';
  };
}
```

### `mergeFunc`

A function that combines the values from each mutator, and returns the final value of the option. See the documentation
on [mutations](./mutations.md) for more info.

This does not require `mutators` to be set.

### `mutators`

A list of module paths, where each of the linked modules expose a mutation of this option. See the documentation on
[mutations](./mutations.md) for more info.

If set, `mergeFunc` must be defined.

### `options`

A set of "sub-options" for the module. This gives an experience similar to submodules from `lib.evalModules`. However,
In most cases, `types.struct` should be used instead. See the documentation on [suboptions](./suboptions.md) for more
info.

If an option defines `options`, it cannot specify `type`, `default`, `mutators`, or `mergeFunc`.
