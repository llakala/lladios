# Module Assertions

The `assertions` attribute is a list of assertions, each of which is an attribute set in the following format:

```nix
{
  verify = { options, inputs }: <bool>;
  explain = { options, inputs }: "error message";
}
```

## `verify`

Adios will ensure that this statement evaluates to ture, and will throw an error otherwise.

## `explain`

Allows you to use context to describe the nature of the error.
