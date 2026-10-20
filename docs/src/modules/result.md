# Callable Modules

Adios modules can be made *callable* by adding a `result` attribute. After the module is loaded, adios will add a
functor to modules with a `result` attribute. This functor will take an attibute set as an argument. The attribute
set can contain any of the options defined in the module's `options` attribute, and will override the `default` for
each of those options.

`result` is an attribute that will determine what the module returns once this functor is called. In the majority
of cases, you'll want it to be a promise:

```nix
{
  result = adios.promise ({ inputs, options, results }: ...);
}
```
