# Options Reference
Adios module definitions may have an `options` attribute within the module's attribute set. These options can be overridden by consumers of the module (once it is loaded) by directly setting them within the attribute set the loaded module is called with.

`options` is an attribute set of options, each of which is an attribute set containing any of the following attributes:

### `type`
This is a type defined with adios's lightly modified version of [korora](https://github.com/adisbladis/korora). When the option is set by a consumer, an error will be thrown if the option's type is different from the type of what the consumer set the option to.

### `description`
A string describing the option.

### `example`
An example of a possible value the option could be set to by a consumer.

### `default`
The fallback for the option's value. If unset, it will error if `defaultFunc` isn't set and the option wasn't set by a consumer.

### `defaultFunc`
Same as default, but is instead a function that has access to the module's `inputs` and other `options`. If unset, it will error if `default` isn't set and the option wasn't set by a consumer.

### `mutatorType`
A type defined with korora that mutators to the module will be type checked against.

### `mutators`
A list of paths to apply mutators from.

### `mergeFunc`
If `mutatorType` and `mutators` are set, this must also be set.

A function with access to the module's `mutators`, `options`, and `inputs`. The result of this function will be used as the final value for the option.
