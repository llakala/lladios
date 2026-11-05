# Installation

To access the `adios` attribute set, use your favorite pinning tool, and import the root
of this repo. With flakes, it is more idiomatic to use this repo's `adios` flake output.

```nix
# Pinning with flakes.
{
  inputs = {
    adios.url = "github:llakala/lladios";
  };

  outputs =
    inputs:
    let
      inherit (inputs.adios) adios; # alternatively `adios = inputs.adios.adios;`
    in
    # use adios as needed
}
```

```nix
# Pinning with npins (or any similar source-based pinning tool)
let
  sources = import ./npins;

  adios = import sources.adios;
in
  # use adios as needed
```
