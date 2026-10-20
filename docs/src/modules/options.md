# Module Options

The `options` attribute is an attribute set of options or promises that resolve to options. An option is an attribute set in the following format:

```nix
{
  type = adios.types.<type>;
  default = "default value";
  description = "description of the option";
  example = "something the option could be set to";
  mergeFunc = { mutators, options, inputs }: "foo";
  mutators = [ "/path/to/mutation" ];
}
```

Each option can be overridden by users of the module once the module is loaded.

### `type`

The type of the option, defined with adios' type system (korora). The option will throw an error if the value defined by
the user is not of this type.

### `default`

The default value the option will use if it is not set by the user of the module. Optional, but if not set, the user of
the module must set it or the option will throw an error.

### `description`

An optional description of the option, for reference and documentation generation.

### `example`

An optional example of a possible value the option could be set to by a user, for reference and documentation
generation.

### `mergeFunc`

A function that combines the option's defined `mutators` (including what the user has set the option to) with the
module's `inputs` and `options` to produce the final value of the option that will be used. Optional, but if set,
`mutators` *must* be defined, otherwise the module will throw an error.

### `mutators`

A list of paths for modules to pull *mutations* for this option from. Will be passed into `mergeFunc` as `mutators`,
along with what the user has set the option to (or what the option's `default` is if the user has not set the option.)
Optional, but if set, `mergeFunc` *must* be defined, otherwise the module will throw an error.
