# `adios.lib.importModules`

`importModules` is a helper function that automatically imports all modules within a directory.

Given this directory structure:

```
./modules
├── default.nix
├── foo.nix
└── bar
    ├── baz
    │   └── default.nix
    └── default.nix
```

If the root module at `default.nix` is defined like this:
```nix
adios: {
  modules = adios.lib.importModules {
    directory = ./.;
  };
}
```

Then `importTree` will generate:
```nix
adios: {
  modules = {
    foo = import ./foo.nix adios;
    bar = import ./bar adios;
  };
}
```

Notably, `importModules` is *not* recursive - the `baz/` module was completely ignored.
If the `bar` module wants to depend on another module defined within its folder, it should import those modules itself,
like this:
```nix
adios: {
  modules = adios.lib.importModules {
    directory = ./.;
  };
}
```

## Custom Arguments
You can override the arguments `importModules` uses to call modules with, by changing the `args` option. This option
defaults to the `adios` attrset, but you can override to, for example, add more library functions.
```nix
adios: {
  modules = adios.lib.importModules {
    directory = ./.;
    args = adios // {
      types = adios.types // {
        inherit customType;
      };
      lib = adios.lib // {
        inherit customFunction;
      };
    };
  };
}
```
