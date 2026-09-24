# Mutators
Modules usually need the ability to modify other modules. In the NixOS module system, this is done by giving every
module the ability to modify every option, which prevents lazy importing of modules. Adios is able to preserve lazy
importing of modules by using *mutators*.

Module definitions can contain a `mutations` attribute. `mutations` is an attribute set of paths, each of which is an
attribute set of mutations to a module located at that path. Each mutation is a function that has access to the
`options` and `inputs` of the module that is *defining* the mutation (not the module being targeted) and returns
something of whatever type the target option is.

Module options may define a list of `mutators`. Each is a path pointing to a module that has a `mutation` defined for
that option. The option's `mergeFunc` will take the option's defined `mutators` as well as the module's `inputs` and
other `options` to compute the final value for the option.
```nix
let
  adios = import (fetchTarball "https://github.com/llakala/lladios/archive/main.tar.gz");

  root = {
    modules = {
      hello = {
        options.names = {
          type = adios.types.string;
          mutators = [ "./." "/friends" ];
          mergeFunc = { mutators }: builtins.concatStringsSep ", " mutators;
        };

        mutations."/hello".names = _: "Bob";

        impl = { options }: "Hello, ${options.names}!";
      };

      friends = {
        mutations."/hello".names = _: "Alice";
      };
    };
  };

  loadedModule = adios root {};
in
  loadedModule.modules.hello {} # -> "Hello, Bob, Alice!"
```
