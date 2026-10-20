# Mutating Modules

The `mutations` attribute is an attribute set of attribute sets of mutators. The first attribute is a path pointing to a
module and the second is the option of that module that the mutator will mutate. Each of these mutators can either be a
normal expression or a promise returning one.

```nix
{
  name = "mutating-module";
  
  mutations."/path/to/target-module".target-option = "foo";
}
```

Then, the target module's option may list the mutators it wants to use as well as a function to merge all of the
mutators together:

```nix
{
  name = "target-module";
  
  options.<target-option> = {
    type = adios.types.<type>;
    default = <default>; # will be added to list of 'mutators' below
    mergeFunc = { options, mutators, inputs }: <final-result-of-option>;
    mutators = [ "path/to/mutating-module" ]; # additional mutators to add to the list of 'mutators' above
  };
}
```

each of which is an attribute set of mutations to the target module. Each mutation is a value or promise that the target
module option can optionally choose to add by specifying the path to the module that defined the mutation within the
option's `mutators` attribute. The target option can then specify a `mergeFunc` that will merge all of the mutators that
options defines together.
