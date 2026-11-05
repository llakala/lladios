# `merge.lists.concat`

## Behavior

This function takes the raw data from mutators each providing a list, like this:
```nix
{{#include mutatorsBefore.nix}}
```

And turns it into:

```nix
{{#include mutatorsAfter.nix}}
```

The final result is sorted by the order of the module paths in the `mutators` list.

## Usage

This should be used when:

1. You're creating an option that expects to be mutated.
1. The final result is expected to be a list of your desired value.
1. Each of the mutators provide a list of your desired value.

For example:

```nix
{{#include example.nix}}
```
